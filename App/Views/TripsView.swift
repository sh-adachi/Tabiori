import SwiftUI

struct TripsView: View {
    @Environment(AppStore.self) private var store
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var query = ""
    @State private var filter = TripFilter.upcoming

    enum TripFilter: String, CaseIterable {
        case upcoming = "これから", past = "旅の記録", all = "すべて"
    }

    private var visibleTrips: [Trip] {
        store.trips.filter { trip in
            let today = TripDate.calendar(for: trip).startOfDay(for: Date())
            let isPast = TripDate.calendar(for: trip).startOfDay(for: trip.endDate) < today
            let matchesDate = filter == .all || (filter == .past ? isPast : !isPast)
            let text = [trip.title, trip.destination, trip.notes].joined(separator: " ")
            return matchesDate && (query.isEmpty || text.localizedStandardContains(query))
        }.sorted { filter == .past ? $0.startDate > $1.startDate : $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if store.loadFailed {
                        ContentUnavailableView {
                            Label("旅行を読み込めません", systemImage: "externaldrive.badge.exclamationmark")
                        } description: { Text("保存データはそのまま残っています。時間をおいて再読み込みしてください。") }
                        actions: { Button("再読み込み") { store.reload() }.buttonStyle(.borderedProminent) }
                    } else if store.trips.isEmpty {
                        welcome
                    } else {
                        Picker("旅行の表示", selection: $filter) {
                            ForEach(TripFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        if visibleTrips.isEmpty {
                            ContentUnavailableView("旅行がありません", systemImage: "suitcase.rolling", description: Text(query.isEmpty ? "新しい旅の計画を立てましょう。" : "別のキーワードで探してみてください。"))
                        }
                        ForEach(visibleTrips) { trip in
                            NavigationLink(value: trip.id) { TripCard(trip: trip) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("trip.card.\(trip.id.uuidString)")
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                            Text("旅の情報は、このiPhoneに保存されます")
                        }.font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 4)
                    }
                }.padding(20).padding(.bottom, 28)
            }
            .background(AppTheme.canvas)
            .navigationTitle("たびおり")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "旅行名・行き先・メモを検索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("設定").accessibilityIdentifier("settings.open")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("旅行を作成").accessibilityIdentifier("trip.add").disabled(store.loadFailed)
                }
            }
            .navigationDestination(for: UUID.self) { TripDetailView(tripID: $0) }
            .sheet(isPresented: $showEditor) { TripEditorView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("お知らせ", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("閉じる", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            SmallLabel(text: "TABIORI  /  YOUR TRAVEL COMPANION")
            Text("次の旅を、\nひとつのしおりに。")
                .font(.system(size: 30, weight: .bold, design: .serif)).lineSpacing(4)
            Text("予定も、チケットも、気になる場所も。")
                .font(.subheadline).foregroundStyle(.secondary)
        }.padding(.top, 12)
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .bottomLeading) {
                TravelArtwork()
                VStack(alignment: .leading, spacing: 10) {
                    Text("LET’S GO SOMEWHERE").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.65))
                    Text("旅の楽しみは、\n計画から。")
                        .font(.system(size: 28, weight: .medium, design: .serif)).foregroundStyle(.white)
                }.padding(25)
            }.frame(height: 236).clipShape(RoundedRectangle(cornerRadius: 26))
            VStack(alignment: .leading, spacing: 20) {
                feature("calendar", "日ごとの旅程", "移動、食事、宿泊を時間順に。")
                feature("doc.on.doc", "予約資料をひとまとめ", "写真やPDFを、旅先でもすぐに。")
                feature("map", "行きたい場所を地図に", "お店や目的地を保存して確認。")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            Button { showEditor = true } label: {
                Label("最初の旅行を作成", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.borderedProminent).clipShape(RoundedRectangle(cornerRadius: 16))
            Button("サンプルの旅を見てみる") { store.addSample() }
                .font(.subheadline).accessibilityIdentifier("sample.add")
            Text("サンプルの予定・金額は操作体験用です。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            SymbolBadge(symbol: symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct TripCard: View {
    let trip: Trip
    private var countdown: String {
        let calendar = TripDate.calendar(for: trip)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: trip.startDate)).day ?? 0
        if calendar.startOfDay(for: trip.endDate) < today { return "旅の記録" }
        return days > 0 ? "出発まで \(days) 日" : "旅行中"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                TravelArtwork(compact: true)
                VStack(alignment: .leading, spacing: 9) {
                    Text(countdown).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.14), in: Capsule())
                    Text(trip.destination.isEmpty ? "MY JOURNEY" : trip.destination).font(.system(size: 28, weight: .medium, design: .serif))
                }.foregroundStyle(.white).padding(20)
            }.frame(height: 155)
            VStack(alignment: .leading, spacing: 12) {
                Text(trip.title).font(.headline)
                Text(TripDate.range(trip)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("\(trip.items.count)件の予定", systemImage: "calendar")
                    Label("\(trip.attachments.count)件の書類", systemImage: "paperclip")
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").foregroundStyle(AppTheme.teal)
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.background(AppTheme.card).clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("たびおり / Tabiori", systemImage: "paperplane.fill").font(.title3.weight(.semibold)).foregroundStyle(AppTheme.teal)
                    Text("旅の予定を、一冊のしおりのように。")
                    Text("バージョン \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("データと通信") {
                    Text("旅行・メモ・添付ファイルはこの端末のアプリ専用領域に保存します。アプリを削除するとデータも削除されます。")
                    Text("地図表示・場所検索にはインターネット接続が必要です。保存した予定、メモ、添付ファイルはオフラインでも確認できます。")
                    Text("クラウド同期、予約メールの自動取込、時刻表・運行状況の自動更新には対応していません。")
                }
                Section("使い方") {
                    Text("旅行を作成して予定を追加します。予定に場所を設定すると地図に表示されます。写真・PDFは旅行の「書類」から添付できます。")
                    Text("予定の時刻は旅行で選んだタイムゾーンに統一します。海外への移動は到着時刻もこのタイムゾーンで入力してください。")
                    Text("費用は旅行で設定した通貨で合計します。入力金額を自動換算する機能はありません。")
                }
            }.navigationTitle("たびおりについて").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}

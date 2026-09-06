import SwiftUI

struct ItemEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    private let originalItem: ItineraryItem?
    private let initialDate: Date?
    @State private var draft: ItineraryItem
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var cost: String
    @State private var initialized = false
    @State private var showingPlaces = false
    @State private var errorMessage: String?

    init(tripID: UUID, item: ItineraryItem? = nil, initialDate: Date? = nil) {
        self.tripID = tripID
        originalItem = item
        self.initialDate = initialDate
        let initial = item ?? ItineraryItem(title: "", startDate: Date())
        _draft = State(initialValue: initial)
        _hasEndDate = State(initialValue: initial.endDate != nil)
        _endDate = State(initialValue: initial.endDate ?? initial.startDate.addingTimeInterval(3600))
        _cost = State(initialValue: EditorAmount.string(initial.cost))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("予定のこと") {
                    Picker("種類", selection: $draft.kind) {
                        ForEach(ItemKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField(titlePlaceholder, text: $draft.title)
                        .accessibilityIdentifier("item.title")
                }
                Section {
                    DatePicker(draft.kind.isTransport ? "出発" : "開始", selection: $draft.startDate)
                    Toggle(draft.kind.isTransport ? "到着日時を記録" : "終了日時を記録", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker(draft.kind.isTransport ? "到着" : "終了", selection: $endDate, in: draft.startDate...)
                    }
                } header: { Text("日時") } footer: {
                    Text("\(trip?.timeZoneIdentifier ?? "Asia/Tokyo") の日時で入力します。\(trip.map { " 旅の日程：\(TripDate.range($0))" } ?? "")")
                }
                if draft.kind.isTransport {
                    Section("移動・予約") {
                        TextField("出発駅・空港・バス停", text: $draft.departure)
                        TextField("到着駅・空港・バス停", text: $draft.arrival)
                        TextField("便名・列車名（のぞみ 101 号など）", text: $draft.serviceNumber)
                        reservationField
                    }
                } else {
                    Section("予約") { reservationField }
                }
                Section {
                    Button { showingPlaces = true } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(AppTheme.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.location?.name ?? "場所を追加").foregroundStyle(.primary)
                                Text(draft.location?.address ?? "施設名・住所で検索、または手動で登録")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("item.place")
                    if draft.location != nil {
                        Button("場所を解除", role: .destructive) { draft.location = nil }
                    }
                } header: { Text(draft.kind.isTransport ? "目的地の場所" : "場所") } footer: {
                    Text("登録した場所は、旅のマップにピンで表示されます。")
                }
                Section("費用・メモ") {
                    HStack {
                        Text("費用")
                        TextField("0", text: $cost).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("予定の費用")
                        Text(trip?.currencyCode ?? "JPY").foregroundStyle(.secondary)
                    }
                    TextField(notesPlaceholder, text: $draft.notes, axis: .vertical).lineLimit(4...12)
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .environment(\.timeZone, trip?.timeZone ?? TimeZone(identifier: "Asia/Tokyo")!)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(originalItem == nil ? "予定を追加" : "予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).fontWeight(.semibold).accessibilityIdentifier("item.save")
                }
            }
            .sheet(isPresented: $showingPlaces) {
                PlacePickerView(selectedPlace: draft.location) { draft.location = $0 }
            }
            .onAppear(perform: setInitialDate)
            .onChange(of: draft.startDate) { _, newDate in
                if endDate < newDate { endDate = newDate }
            }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(AppTheme.teal)
    }

    private var trip: Trip? { store.trip(id: tripID) }
    private var reservationField: some View {
        TextField("予約番号（任意）", text: $draft.reservationCode)
            .textInputAutocapitalization(.characters).autocorrectionDisabled()
    }
    private var titlePlaceholder: String {
        switch draft.kind {
        case .restaurant: "店名・食事の予定"
        case .hotel: "ホテル・宿泊先"
        case .train, .flight, .bus: "予定の名前（東京 → 京都など）"
        default: "予定の名前"
        }
    }
    private var notesPlaceholder: String {
        switch draft.kind {
        case .restaurant: "食べたいメニュー、営業時間、予約人数、アレルギーなど"
        case .train, .flight, .bus: "座席・乗り場、荷物の注意点、乗り換えなど"
        case .hotel: "チェックイン方法、宿泊人数、連絡先など"
        default: "営業時間、やりたいこと、連絡先など"
        }
    }

    private func setInitialDate() {
        guard !initialized else { return }
        initialized = true
        guard originalItem == nil, let trip else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone
        let firstDay = calendar.startOfDay(for: trip.startDate)
        let lastDay = calendar.startOfDay(for: trip.endDate)
        let requestedDay = calendar.startOfDay(for: initialDate ?? trip.startDate)
        let selectedDay = min(max(requestedDay, firstDay), lastDay)
        draft.startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        endDate = draft.startDate.addingTimeInterval(3600)
    }

    private func save() {
        guard var trip else { errorMessage = "この旅が見つかりません。画面を閉じて再度お試しください。"; return }
        guard let amount = EditorAmount.parse(cost) else { errorMessage = "費用は 0 以上の数値で入力してください。"; return }
        draft.cost = amount
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.endDate = hasEndDate ? endDate : nil
        if let index = trip.items.firstIndex(where: { $0.id == draft.id }) { trip.items[index] = draft }
        else { trip.items.append(draft) }
        if store.save(trip) { store.errorMessage = nil; dismiss() }
        else {
            errorMessage = store.errorMessage ?? "予定を保存できませんでした。"
            store.errorMessage = nil
        }
    }
}

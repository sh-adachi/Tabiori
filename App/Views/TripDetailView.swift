import SwiftUI

struct TripDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    @State private var editing = false
    @State private var addingItem = false
    @State private var deleting = false
    @State private var selectedDay: Date?

    var body: some View {
        Group {
            if let trip = store.trip(id: tripID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        tripHeader(trip)
                        quickLinks(trip)
                        timeline(trip)
                        if !trip.notes.isEmpty {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("旅のメモ", systemImage: "text.alignleft").font(.subheadline.weight(.semibold))
                                    Text(trip.notes).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }
                        }
                    }.padding(20).padding(.bottom, 24)
                }
                .background(AppTheme.canvas)
                .navigationTitle(trip.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { addingItem = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("予定を追加").accessibilityIdentifier("item.add")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("旅行を編集", systemImage: "pencil") { editing = true }
                            ShareLink(item: TripExport.text(for: trip, includeReservationCodes: store.settings.includesReservationCodesInShare)) { Label("旅程を共有", systemImage: "square.and.arrow.up") }
                            Button("旅行を削除", systemImage: "trash", role: .destructive) { deleting = true }
                        } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("旅行のメニュー")
                    }
                }
                .sheet(isPresented: $editing) { TripEditorView(trip: trip) }
                .sheet(isPresented: $addingItem) {
                    ItemEditorView(tripID: tripID, initialDate: selectedDay.flatMap { TripDate.days(trip).contains($0) ? $0 : nil })
                }
                .confirmationDialog("「\(trip.title)」を削除しますか？", isPresented: $deleting, titleVisibility: .visible) {
                    Button("旅行と添付ファイルを削除", role: .destructive) { if store.deleteTrip(id: tripID) { dismiss() } }
                } message: { Text("この旅行の予定、書類、チェックリストが削除されます。この操作は取り消せません。") }
            } else {
                ContentUnavailableView("旅行が見つかりません", systemImage: "suitcase")
            }
        }
    }

    private func tripHeader(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SmallLabel(text: "YOUR JOURNEY")
                Spacer()
                Text("\(TripDate.days(trip).count)日間").font(.caption.weight(.medium)).foregroundStyle(AppTheme.teal)
            }
            Text(trip.destination.isEmpty ? trip.title : trip.destination)
                .font(.system(size: 34, weight: .bold, design: .serif))
            Label(TripDate.range(trip), systemImage: "calendar")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            NavigationLink { BudgetView(tripID: tripID) } label: {
                HStack(spacing: 12) {
                    SymbolBadge(symbol: "yensign.circle")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("旅の費用").font(.caption).foregroundStyle(.secondary)
                        Text(TripDate.money(trip.totalCost, currency: trip.currencyCode)).font(.title3.weight(.semibold)).foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if trip.budget > 0 {
                            Text("予算 \(TripDate.money(trip.budget, currency: trip.currencyCode))").font(.caption).foregroundStyle(.secondary)
                            Text(trip.totalCost > trip.budget ? "予算を超えています" : "費用の内訳を見る").font(.caption2).foregroundStyle(trip.totalCost > trip.budget ? AppTheme.coral : AppTheme.teal)
                        } else { Text("内訳・予算").font(.caption).foregroundStyle(AppTheme.teal) }
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }.padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
        }.padding(.top, 4)
    }

    private func quickLinks(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            NavigationLink { TripMapView(tripID: tripID) } label: {
                quickLink("map", "地図", "\(trip.items.filter { $0.location != nil }.count)か所")
            }.accessibilityIdentifier("trip.tab.map")
            NavigationLink { AttachmentsView(tripID: tripID) } label: {
                quickLink("doc.on.doc", "書類", "\(trip.attachments.count)件")
            }.accessibilityIdentifier("trip.tab.documents")
            NavigationLink { ChecklistView(tripID: tripID) } label: {
                quickLink("checklist", "準備", "\(trip.checklist.filter(\.isChecked).count)/\(trip.checklist.count)")
            }.accessibilityIdentifier("trip.tab.checklist")
        }.buttonStyle(.plain)
    }

    private func quickLink(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(AppTheme.teal)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func timeline(_ trip: Trip) -> some View {
        let days = TripDate.days(trip)
        let currentDay = selectedDay.flatMap { days.contains($0) ? $0 : nil } ?? days.first ?? trip.startDate
        let items = trip.sortedItems.filter { TripDate.calendar(for: trip).isDate($0.startDate, inSameDayAs: currentDay) }
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("旅のスケジュール").font(.title3.weight(.bold))
                Spacer()
                Text("\(trip.items.count) PLANS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(.secondary)
            }.accessibilityIdentifier("trip.tab.itinerary")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.element) { index, day in
                        Button { selectedDay = day } label: {
                            VStack(spacing: 6) {
                                Text("DAY \(index + 1)").font(.system(size: 10, weight: .bold, design: .monospaced))
                                Text(TripDate.format(day, pattern: "M/d E", timeZone: trip.timeZone)).font(.subheadline.weight(.semibold))
                            }.padding(.horizontal, 17).padding(.vertical, 12)
                                .foregroundStyle(currentDay == day ? .white : AppTheme.ink)
                                .background(currentDay == day ? AppTheme.teal : AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).accessibilityAddTraits(currentDay == day ? .isSelected : [])
                    }
                }
            }
            Text("\(TripDate.day(currentDay, timeZone: trip.timeZone)) ・ \(trip.timeZoneIdentifier)")
                .font(.caption).foregroundStyle(.secondary)
            if items.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus").font(.largeTitle).foregroundStyle(AppTheme.teal.opacity(0.7))
                    Text("この日の予定を加えましょう").font(.subheadline.weight(.medium))
                    Text("移動や食事、気になるスポットを\n時間順に並べて確認できます。")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("予定を追加") { addingItem = true }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity).padding(24).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink { ItemDetailView(tripID: tripID, itemID: item.id) } label: {
                            TimelineRow(item: item, timeZone: trip.timeZone, isLast: index == items.count - 1)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TimelineRow: View {
    let item: ItineraryItem
    let timeZone: TimeZone
    let isLast: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                Text(TripDate.time(item.startDate, timeZone: timeZone)).font(.system(.caption, design: .monospaced).weight(.semibold))
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle.fill")
                    .font(.system(size: item.isCompleted ? 16 : 9)).foregroundStyle(item.kind.tint)
                Rectangle().fill(isLast ? .clear : item.kind.tint.opacity(0.18)).frame(width: 1).frame(maxHeight: .infinity)
            }.frame(width: 43)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label(item.kind.title, systemImage: item.kind.symbol).font(.caption.weight(.medium)).foregroundStyle(item.kind.tint)
                    Spacer()
                    if item.isCompleted { Text("完了").font(.caption2).foregroundStyle(.secondary) }
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary)
                }
                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.ink).multilineTextAlignment(.leading)
                if item.kind.isTransport && (!item.departure.isEmpty || !item.arrival.isEmpty) {
                    Text("\(item.departure.isEmpty ? "出発地未設定" : item.departure) → \(item.arrival.isEmpty ? "到着地未設定" : item.arrival)")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                } else if let location = item.location {
                    Label(location.name, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if !item.serviceNumber.isEmpty {
                    Text(item.serviceNumber).font(.caption2.monospaced()).foregroundStyle(item.kind.tint)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(item.kind.tint.opacity(0.07), in: Capsule())
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 19))
                .padding(.bottom, 14)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

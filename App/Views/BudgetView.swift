import SwiftUI

struct BudgetView: View {
    @Environment(AppStore.self) private var store
    let tripID: UUID
    @State private var editing = false

    var body: some View {
        Group {
            if let trip = store.trip(id: tripID) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            SmallLabel(text: "TRAVEL BUDGET")
                            Text(TripDate.money(trip.totalCost, currency: trip.currencyCode)).font(.system(size: 34, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                            Text("入力した予定の費用合計").font(.caption).foregroundStyle(.secondary)
                            if trip.budget > 0 {
                                ProgressView(value: min(trip.totalCost, trip.budget), total: trip.budget)
                                    .tint(trip.totalCost > trip.budget ? AppTheme.coral : AppTheme.teal)
                                HStack {
                                    Text("予算 \(TripDate.money(trip.budget, currency: trip.currencyCode))")
                                    Spacer()
                                    Text("\(trip.totalCost > trip.budget ? "超過" : "残り") \(TripDate.money(abs(trip.budget - trip.totalCost), currency: trip.currencyCode))")
                                }.font(.caption).foregroundStyle(trip.totalCost > trip.budget ? AppTheme.coral : .secondary)
                            }
                            Button(trip.budget > 0 ? "予算を変更" : "予算を設定") { editing = true }.font(.subheadline)
                        }.padding(.vertical, 12)
                    }
                    Section("種類ごとの費用") {
                        ForEach(ItemKind.allCases) { kind in
                            let total = trip.items.filter { $0.kind == kind }.reduce(0) { $0 + $1.cost }
                            HStack {
                                Label(kind.title, systemImage: kind.symbol).foregroundStyle(kind.tint)
                                Spacer()
                                Text(TripDate.money(total, currency: trip.currencyCode)).foregroundStyle(AppTheme.ink)
                            }.font(.subheadline).padding(.vertical, 3)
                        }
                    }
                    Section {
                        ForEach(trip.sortedItems.filter { $0.cost > 0 }) { item in
                            NavigationLink { ItemDetailView(tripID: tripID, itemID: item.id) } label: {
                                HStack {
                                    Text(item.title).font(.subheadline)
                                    Spacer()
                                    Text(TripDate.money(item.cost, currency: trip.currencyCode)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: { Text("費用を入力した予定") }
                    footer: { Text("すべて\(trip.currencyCode)で集計します。為替換算や支払いの処理は行いません。未入力の費用は0として扱います。") }
                }.navigationTitle("旅の費用").navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: $editing) { TripEditorView(trip: trip) }
            } else { ContentUnavailableView("旅行が見つかりません", systemImage: "yensign.circle") }
        }
    }
}

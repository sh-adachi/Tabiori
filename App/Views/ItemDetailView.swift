import SwiftUI
import MapKit

struct ItemDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    let itemID: UUID
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        Group {
            if let trip = store.trip(id: tripID), let item = trip.items.first(where: { $0.id == itemID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SymbolBadge(symbol: item.kind.symbol, color: item.kind.tint)
                        Text(item.title).font(.system(size: 29, weight: .bold, design: .serif))
                        Label(item.kind.title, systemImage: item.kind.symbol).font(.subheadline).foregroundStyle(item.kind.tint)
                        PaperCard {
                            VStack(alignment: .leading, spacing: 14) {
                                detail("日時", "\(TripDate.day(item.startDate, timeZone: trip.timeZone)) \(TripDate.time(item.startDate, timeZone: trip.timeZone))")
                                if let end = item.endDate { detail("終了", "\(TripDate.day(end, timeZone: trip.timeZone)) \(TripDate.time(end, timeZone: trip.timeZone))") }
                                Text(trip.timeZoneIdentifier).font(.caption2).foregroundStyle(.secondary)
                                if !item.departure.isEmpty { Divider(); detail("出発", item.departure) }
                                if !item.arrival.isEmpty { detail("到着", item.arrival) }
                                if !item.serviceNumber.isEmpty { detail("便名・列車名", item.serviceNumber) }
                                if !item.reservationCode.isEmpty { Divider(); detail("予約番号", item.reservationCode) }
                                if item.cost > 0 { Divider(); detail("費用", TripDate.money(item.cost, currency: trip.currencyCode)) }
                            }
                        }
                        if let place = item.location {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(place.name, systemImage: "mappin.and.ellipse").font(.headline)
                                    if !place.address.isEmpty { Text(place.address).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled) }
                                    HStack {
                                        NavigationLink("旅の地図で見る") { TripMapView(tripID: tripID) }
                                        Spacer()
                                        Button("経路を調べる", systemImage: "arrow.triangle.turn.up.right.diamond") {
                                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
                                            mapItem.name = place.name
                                            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
                                        }
                                    }.font(.caption.weight(.medium))
                                }
                            }
                        }
                        if !item.notes.isEmpty {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("メモ", systemImage: "note.text").font(.headline)
                                    Text(item.notes).font(.subheadline).textSelection(.enabled)
                                }
                            }
                        }
                        NavigationLink { AttachmentsView(tripID: tripID) } label: {
                            Label("予約資料・写真を見る", systemImage: "paperclip").font(.subheadline)
                        }.padding(.vertical, 8)
                        Button {
                            var updated = trip
                            if let index = updated.items.firstIndex(where: { $0.id == itemID }) {
                                updated.items[index].isCompleted.toggle()
                                store.save(updated)
                            }
                        } label: {
                            Label(item.isCompleted ? "完了済み（タップして戻す）" : "この予定を完了にする", systemImage: item.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.buttonStyle(.borderedProminent).accessibilityIdentifier("item.complete").accessibilityValue(item.isCompleted ? "完了" : "未完了")
                        Button("予定を削除", role: .destructive) { deleting = true }.font(.subheadline).frame(maxWidth: .infinity).padding(.top, 8)
                    }.padding(22)
                }.background(AppTheme.canvas).navigationTitle("予定の詳細").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("編集") { editing = true }.accessibilityIdentifier("item.edit") } }
                    .sheet(isPresented: $editing) { ItemEditorView(tripID: tripID, item: item) }
                    .confirmationDialog("この予定を削除しますか？", isPresented: $deleting, titleVisibility: .visible) {
                        Button("予定を削除", role: .destructive) {
                            var updated = trip
                            updated.items.removeAll { $0.id == itemID }
                            // Keep booking files; only remove their association with the deleted item.
                            for index in updated.attachments.indices where updated.attachments[index].itemID == itemID { updated.attachments[index].itemID = nil }
                            if store.save(updated) { dismiss() }
                        }
                    } message: { Text("添付した写真・PDFは旅行の書類に残ります。") }
            } else { ContentUnavailableView("予定が見つかりません", systemImage: "calendar") }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).textSelection(.enabled)
        }
    }
}

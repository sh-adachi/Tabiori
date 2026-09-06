import MapKit
import SwiftUI

struct TripMapView: View {
    @Environment(AppStore.self) private var store
    let tripID: UUID
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedItemID: UUID?
    @State private var showingStops = false

    private var trip: Trip? { store.trip(id: tripID) }
    private var locatedItems: [ItineraryItem] { trip?.sortedItems.filter { $0.location != nil } ?? [] }
    private var selectedItem: ItineraryItem? { locatedItems.first { $0.id == selectedItemID } }

    var body: some View {
        Group {
            if locatedItems.isEmpty {
                ContentUnavailableView {
                    Label("旅の行き先を、地図に。", systemImage: "map")
                } description: {
                    Text("予定の編集画面で「場所を追加」すると、移動先や飲食店をまとめて確認できます。")
                }
            } else {
                Map(position: $camera) {
                    ForEach(locatedItems) { item in
                        if let place = item.location {
                            Annotation(place.name, coordinate: place.coordinate) {
                                Button {
                                    withAnimation(.easeInOut) { selectedItemID = item.id }
                                } label: {
                                    Image(systemName: item.kind.symbol)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: selectedItemID == item.id ? 48 : 38, height: selectedItemID == item.id ? 48 : 38)
                                        .background(item.kind.tint, in: Circle())
                                        .overlay(Circle().stroke(.white, lineWidth: 3))
                                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(item.title)、\(place.name)")
                                .accessibilityIdentifier("map.pin.\(item.id.uuidString)")
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls { MapCompass(); MapScaleView() }
                .overlay(alignment: .topLeading) {
                    Button { showingStops = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet")
                            Text("\(locatedItems.count) 件の行き先")
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(.caption.weight(.semibold)).padding(12)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .accessibilityIdentifier("map.stops").padding()
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation { camera = .automatic }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.headline).padding(12).background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("すべての場所を表示").padding()
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let item = selectedItem, let place = item.location {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(item.kind.title, systemImage: item.kind.symbol)
                                        .font(.caption.weight(.semibold)).foregroundStyle(item.kind.tint)
                                    Text(item.title).font(.headline)
                                }
                                Spacer()
                                Button { selectedItemID = nil } label: {
                                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                                }.accessibilityLabel("場所の詳細を閉じる")
                            }
                            Text("\(TripDate.day(item.startDate, timeZone: trip?.timeZone ?? .current))  \(TripDate.time(item.startDate, timeZone: trip?.timeZone ?? .current))")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(place.name).font(.subheadline.weight(.medium))
                            if !place.address.isEmpty { Text(place.address).font(.caption).foregroundStyle(.secondary) }
                            Button { place.openDirections(mode: store.settings.directionsMode) } label: {
                                Label("Apple マップで経路を調べる", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent).tint(AppTheme.teal)
                        }
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .padding(12)
                    } else {
                        Text("ピンをタップすると、予定と経路を確認できます。")
                            .font(.caption).padding(12).frame(maxWidth: .infinity)
                            .background(.regularMaterial)
                    }
                }
            }
        }
        .navigationTitle("旅のマップ")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.teal)
        .sheet(isPresented: $showingStops) {
            NavigationStack {
                List(locatedItems) { item in
                    if let place = item.location {
                        Button {
                            selectedItemID = item.id
                            camera = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000))
                            showingStops = false
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.kind.symbol).foregroundStyle(item.kind.tint).frame(width: 25)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.headline).foregroundStyle(.primary)
                                    Text(place.name).font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(TripDate.day(item.startDate, timeZone: trip?.timeZone ?? .current))  \(TripDate.time(item.startDate, timeZone: trip?.timeZone ?? .current))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .accessibilityIdentifier("map.stop.\(item.id.uuidString)")
                    }
                }
                .navigationTitle("保存した行き先")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("完了") { showingStops = false } }
                }
            }
            .tint(AppTheme.teal)
        }
    }
}

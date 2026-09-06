import MapKit
import SwiftUI

struct PlacePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedPlace: Place?
    let onSelect: (Place) -> Void
    @State private var query: String
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var activeSearch: MKLocalSearch?
    @State private var manualName: String
    @State private var manualAddress: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var manualError: String?
    @State private var manualExpanded = false

    init(selectedPlace: Place?, onSelect: @escaping (Place) -> Void) {
        self.selectedPlace = selectedPlace
        self.onSelect = onSelect
        _query = State(initialValue: selectedPlace?.name ?? "")
        _manualName = State(initialValue: selectedPlace?.name ?? "")
        _manualAddress = State(initialValue: selectedPlace?.address ?? "")
        _latitude = State(initialValue: selectedPlace.map { String($0.latitude) } ?? "")
        _longitude = State(initialValue: selectedPlace.map { String($0.longitude) } ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.teal)
                        TextField("施設名・住所（京都駅など）", text: $query)
                            .submitLabel(.search).onSubmit(search)
                            .accessibilityIdentifier("place.query")
                        if isSearching { ProgressView() }
                    }
                    Button("場所を検索", action: search)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                        .accessibilityIdentifier("place.search")
                } footer: {
                    Text("検索にはインターネット接続が必要です。選んだ場所の名前・住所・座標を、この旅に保存します。")
                }

                if let searchError {
                    Section {
                        Label(searchError, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary)
                    }
                }
                if hasSearched && !isSearching && results.isEmpty && searchError == nil {
                    Section {
                        ContentUnavailableView("場所が見つかりません", systemImage: "mappin.slash", description: Text("市区町村名を加えるか、下の「手動で登録」をお使いください。"))
                    }
                }
                if !results.isEmpty {
                    Section("検索結果") {
                        ForEach(results) { result in
                            Button {
                                onSelect(result.place)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(AppTheme.teal)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(result.place.name).font(.headline).foregroundStyle(.primary)
                                        Text(result.place.address).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .accessibilityIdentifier("place.result.\(result.id.uuidString)")
                        }
                    }
                }

                Section {
                    Button {
                        withAnimation { manualExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("手動で登録").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: manualExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("place.manual")
                    .accessibilityValue(manualExpanded ? "展開中" : "折りたたみ")
                    if manualExpanded {
                        TextField("場所の名前", text: $manualName).accessibilityIdentifier("place.name")
                        TextField("住所（任意）", text: $manualAddress)
                        TextField("緯度（例：35.0116）", text: $latitude)
                            .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                            .accessibilityIdentifier("place.latitude")
                        TextField("経度（例：135.7681）", text: $longitude)
                            .keyboardType(.numbersAndPunctuation).autocorrectionDisabled()
                            .accessibilityIdentifier("place.longitude")
                        if let manualError { Text(manualError).font(.caption).foregroundStyle(.red) }
                        Button("この場所を登録", action: saveManualPlace).accessibilityIdentifier("place.save")
                    }
                } footer: {
                    Text("検索できない場所も、緯度・経度がわかれば登録できます。緯度は −90〜90、経度は −180〜180 の範囲で入力します。")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("場所を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .onDisappear {
                searchTask?.cancel()
                activeSearch?.cancel()
            }
        }
        .tint(AppTheme.teal)
    }

    private func search() {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        searchTask?.cancel()
        activeSearch?.cancel()
        searchError = nil
        results = []
        hasSearched = true
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = input
        request.resultTypes = [.address, .pointOfInterest]
        if let selectedPlace {
            request.region = MKCoordinateRegion(center: selectedPlace.coordinate, latitudinalMeters: 30_000, longitudinalMeters: 30_000)
        }
        let operation = MKLocalSearch(request: request)
        activeSearch = operation
        searchTask = Task { @MainActor in
            do {
                let response = try await operation.start()
                guard !Task.isCancelled else { return }
                results = response.mapItems.compactMap { item in
                    let coordinate = item.placemark.coordinate
                    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                    return PlaceSearchResult(place: Place(name: item.name ?? input, address: item.placemark.title ?? "", latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            } catch {
                guard !Task.isCancelled else { return }
                if (error as NSError).domain == MKErrorDomain && (error as NSError).code == MKError.placemarkNotFound.rawValue {
                    results = []
                } else {
                    searchError = "場所を検索できませんでした。接続を確認して再度検索するか、手動で登録してください。"
                }
            }
            isSearching = false
        }
    }

    private func saveManualPlace() {
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { manualError = "場所の名前を入力してください。"; return }
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespacesAndNewlines)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespacesAndNewlines)),
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else {
            manualError = "緯度と経度を有効な数値で入力してください。"
            return
        }
        onSelect(Place(name: name, address: manualAddress.trimmingCharacters(in: .whitespacesAndNewlines), latitude: lat, longitude: lon))
        dismiss()
    }
}

private struct PlaceSearchResult: Identifiable {
    let id = UUID()
    let place: Place
}

extension Place {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    func openDirections(mode: DirectionsMode = .transit) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode.mapsValue])
    }
}

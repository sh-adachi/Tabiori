import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    private(set) var trips: [Trip] = []
    var errorMessage: String?
    private(set) var loadFailed = false
    private(set) var settings = AppSettings()
    private(set) var settingsLoadFailed = false
    let scheduleReferenceDate: Date?
    let attachmentRepository: AttachmentRepository
    private let repository: TravelRepository
    private let settingsRepository: AppSettingsRepository

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--uitesting")
        #if DEBUG
        let scheduleFixture = testing && arguments.contains("--schedule-fixture")
        scheduleReferenceDate = scheduleFixture ? ISO8601DateFormatter().date(from: "2026-10-02T00:15:00Z") : nil
        #else
        scheduleReferenceDate = nil
        #endif
        let base = URL.applicationSupportDirectory.appendingPathComponent(testing ? "Tabiori-UITests" : "Tabiori", isDirectory: true)
        // A reset is only permitted for the separate automation data directory.
        if testing && arguments.contains("--reset-data") {
            do { if FileManager.default.fileExists(atPath: base.path) { try FileManager.default.removeItem(at: base) } }
            catch { errorMessage = "テスト用データを初期化できませんでした。\n\(error.localizedDescription)" }
        }
        repository = TravelRepository(directory: base)
        settingsRepository = AppSettingsRepository(directory: base)
        attachmentRepository = AttachmentRepository(directory: base.appendingPathComponent("Attachments", isDirectory: true))
        reload()
        reloadSettings()
        #if DEBUG
        // Seed only the initial fixture launch so saved changes survive relaunches.
        if scheduleFixture && arguments.contains("--reset-data") && trips.isEmpty {
            save(SampleData.makeTrip(now: ISO8601DateFormatter().date(from: "2026-09-17T00:00:00Z")!))
        }
        BookingImportTestFixture.seed(in: self)
        #endif
    }

    func reload() {
        do {
            trips = try repository.load()
            loadFailed = false
            errorMessage = nil
        } catch {
            loadFailed = true
            errorMessage = "保存した旅行を読み込めませんでした。データを保護するため、変更を停止しています。\n\(error.localizedDescription)"
        }
    }

    func trip(id: UUID) -> Trip? { trips.first { $0.id == id } }

    func reloadSettings() {
        do {
            settings = try settingsRepository.load()
            settingsLoadFailed = false
            if !loadFailed { errorMessage = nil }
        } catch {
            settingsLoadFailed = true
            errorMessage = "設定を読み込めませんでした。旅行の記録はそのまま利用できます。設定画面から再読み込みしてください。\n\(error.localizedDescription)"
        }
    }

    @discardableResult func saveSettings(_ value: AppSettings) -> Bool {
        guard !settingsLoadFailed else {
            errorMessage = "設定を読み込めないため、上書きを停止しています。再読み込みしてください。"
            return false
        }
        do {
            let candidate = try value.validated()
            try settingsRepository.save(candidate)
            settings = candidate
            errorMessage = nil
            return true
        } catch {
            errorMessage = "設定を保存できませんでした。\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult func save(_ trip: Trip) -> Bool {
        guard !loadFailed else {
            errorMessage = "データの読み込みに失敗しています。旅行一覧で再読み込みしてください。"
            return false
        }
        var next = trips
        if let index = next.firstIndex(where: { $0.id == trip.id }) { next[index] = trip }
        else { next.append(trip) }
        do {
            try repository.save(next)
            trips = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "保存できませんでした。\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult func deleteTrip(id: UUID) -> Bool {
        guard !loadFailed, let trip = trip(id: id) else { return false }
        let next = trips.filter { $0.id != id }
        do {
            try repository.save(next)
            trips = next
        } catch {
            errorMessage = "旅行を削除できませんでした。\n\(error.localizedDescription)"
            return false
        }
        for attachment in trip.attachments {
            do { try attachmentRepository.remove(attachment) }
            catch { errorMessage = "旅行は削除しましたが、一部の添付ファイルを削除できませんでした。\n\(error.localizedDescription)" }
        }
        return true
    }

    func addSample() { save(SampleData.makeTrip()) }
}

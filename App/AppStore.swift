import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    private(set) var trips: [Trip] = []
    var errorMessage: String?
    private(set) var loadFailed = false
    let attachmentRepository: AttachmentRepository
    private let repository: TravelRepository

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let base = URL.applicationSupportDirectory.appendingPathComponent(testing ? "Tabiori-UITests" : "Tabiori", isDirectory: true)
        // A reset is only permitted for the separate automation data directory.
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-data") {
            do { if FileManager.default.fileExists(atPath: base.path) { try FileManager.default.removeItem(at: base) } }
            catch { errorMessage = "テスト用データを初期化できませんでした。\n\(error.localizedDescription)" }
        }
        repository = TravelRepository(directory: base)
        attachmentRepository = AttachmentRepository(directory: base.appendingPathComponent("Attachments", isDirectory: true))
        reload()
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

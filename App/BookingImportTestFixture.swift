#if DEBUG
import UIKit

@MainActor
enum BookingImportTestFixture {
    private static let trainID = UUID(uuidString: "9C691E2A-43BD-4EA6-B503-000000000001")!
    private static let hotelID = UUID(uuidString: "9C691E2A-43BD-4EA6-B503-000000000002")!

    static func seed(in store: AppStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting"), arguments.contains("--reset-data"),
              (arguments.contains("--booking-fixture") || arguments.contains("--booking-live-fixture")),
              !store.loadFailed, store.trips.isEmpty,
              store.attachmentRepository.directory.deletingLastPathComponent().lastPathComponent == "Tabiori-UITests"
        else { return }

        var trip = SampleData.makeTrip()
        trip.items = []
        do {
            let attachment = try store.attachmentRepository.store(
                data: ticketImage(for: trip), displayName: "予約確認（テスト用）.jpg", kind: .photo
            )
            trip.attachments = [attachment]
            if !store.save(trip) {
                let reason = store.errorMessage ?? "テスト用の旅行を保存できませんでした。"
                do { try store.attachmentRepository.remove(attachment) }
                catch {
                    store.errorMessage = "\(reason)\nテスト用画像の後片付けにも失敗しました：\(error.localizedDescription)"
                }
            }
        } catch {
            store.errorMessage = "テスト用の予約画像を用意できませんでした。\n\(error.localizedDescription)"
        }
    }

    static func extraction(for trip: Trip) -> BookingExtraction? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting"), arguments.contains("--booking-fixture") else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone
        let firstDay = calendar.startOfDay(for: trip.startDate)
        let departure = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: firstDay)!
        let arrival = calendar.date(bySettingHour: 11, minute: 15, second: 0, of: firstDay)!
        return BookingExtraction(destination: "京都", candidates: [
            BookingCandidate(id: trainID, title: "京都行きの新幹線", kind: .train,
                startDate: departure, endDate: arrival, departure: "東京駅", arrival: "京都駅",
                serviceNumber: "のぞみ（テスト用）", reservationCode: "DEMO-ONLY",
                notes: "テスト用の架空の予約です。"),
            BookingCandidate(id: hotelID, title: "京都のホテル", kind: .hotel,
                placeName: "京都のホテル", warnings: ["チェックイン日が読み取れませんでした。開始日時を確認してください。"])
        ])
    }

    private static func ticketImage(for trip: Trip) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1000), format: format)
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.timeZone = trip.timeZone
        date.dateFormat = "yyyy-MM-dd"
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1000))
            let lines = [
                "予約確認 / DEMO TICKET",
                "テスト用・実際の予約ではありません",
                "京都行きの新幹線",
                "日付: \(date.string(from: trip.startDate))",
                "東京駅 09:00 → 京都駅 11:15",
                "のぞみ（テスト用）",
                "予約番号: DEMO-ONLY",
                "京都のホテル / チェックイン日: 未記載"
            ]
            for (index, line) in lines.enumerated() {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: index == 0 ? 48 : 36, weight: index == 0 ? .bold : .regular),
                    .foregroundColor: UIColor.black
                ]
                (line as NSString).draw(in: CGRect(x: 70, y: 70 + index * 105, width: 1060, height: 90),
                                       withAttributes: attributes)
            }
        }
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            throw TravelDataError.invalid("テスト用画像をJPEGに変換できませんでした。")
        }
        return data
    }
}
#endif

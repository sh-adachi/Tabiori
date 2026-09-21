import Foundation

public enum TravelDataError: Error, LocalizedError, Equatable {
    case invalid(String)
    case duplicateID
    case unsafeFileName
    case emptyAttachment
    case attachmentTooLarge
    case attachmentMissing

    public var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .duplicateID: return "データの識別子が重複しています。"
        case .unsafeFileName: return "添付ファイルの保存名が不正です。"
        case .emptyAttachment: return "空のファイルは追加できません。"
        case .attachmentTooLarge: return "添付ファイルは1件25 MB以下にしてください。"
        case .attachmentMissing: return "添付ファイルが見つかりません。"
        }
    }
}

public enum TripValidator {
    public static func validate(_ trip: Trip) throws {
        try requireText(trip.title, message: "旅行のタイトルを入力してください。")
        guard let timeZone = TimeZone(identifier: trip.timeZoneIdentifier) else {
            throw TravelDataError.invalid("旅行のタイムゾーンが不正です。")
        }
        guard trip.startDate.timeIntervalSince1970.isFinite,
              trip.endDate.timeIntervalSince1970.isFinite,
              trip.createdAt.timeIntervalSince1970.isFinite else {
            throw TravelDataError.invalid("旅行の日付が不正です。")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let firstDay = calendar.startOfDay(for: trip.startDate)
        let lastDay = calendar.startOfDay(for: trip.endDate)
        guard lastDay >= firstDay,
              let afterLastDay = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            throw TravelDataError.invalid("旅行の終了日は開始日以降にしてください。")
        }
        guard let dayCount = calendar.dateComponents([.day], from: firstDay, to: afterLastDay).day,
              (1...366).contains(dayCount) else {
            throw TravelDataError.invalid("旅行期間は366日以内にしてください。")
        }
        guard trip.budget.isFinite, trip.budget >= 0 else {
            throw TravelDataError.invalid("予算には0以上の金額を入力してください。")
        }
        try requireText(trip.currencyCode, message: "通貨を設定してください。")
        try requireUnique(trip.items.map(\.id))
        try requireUnique(trip.attachments.map(\.id))
        try requireUnique(trip.checklist.map(\.id))
        guard Set(trip.attachments.map(\.fileName)).count == trip.attachments.count else {
            throw TravelDataError.invalid("同じ添付ファイルが重複しています。")
        }
        let attachmentIDs = Set(trip.attachments.map(\.id))
        for item in trip.items {
            try requireText(item.title, message: "予定のタイトルを入力してください。")
            if let sourceID = item.sourceAttachmentID, !attachmentIDs.contains(sourceID) {
                throw TravelDataError.invalid("予定の読み取り元の画像が見つかりません。")
            }
            guard item.startDate.timeIntervalSince1970.isFinite,
                  item.startDate >= firstDay, item.startDate < afterLastDay else {
                throw TravelDataError.invalid("予定の開始日時を旅行期間内にしてください。")
            }
            if let end = item.endDate {
                guard end.timeIntervalSince1970.isFinite, end >= item.startDate,
                      end < afterLastDay else {
                    throw TravelDataError.invalid("予定の終了日時を開始日時以降、旅行期間内にしてください。")
                }
            }
            guard item.cost.isFinite, item.cost >= 0 else {
                throw TravelDataError.invalid("予定の費用には0以上の金額を入力してください。")
            }
            if let location = item.location {
                guard location.latitude.isFinite, location.longitude.isFinite,
                      (-90...90).contains(location.latitude),
                      (-180...180).contains(location.longitude) else {
                    throw TravelDataError.invalid("緯度は−90〜90、経度は−180〜180の範囲で入力してください。")
                }
            }
        }
        guard trip.totalCost.isFinite else {
            throw TravelDataError.invalid("費用の合計が大きすぎます。")
        }
        let itemIDs = Set(trip.items.map(\.id))
        for attachment in trip.attachments {
            try AttachmentFileName.validate(attachment)
            try requireText(attachment.displayName, message: "添付ファイルの名前を入力してください。")
            guard attachment.createdAt.timeIntervalSince1970.isFinite else {
                throw TravelDataError.invalid("添付ファイルの日付が不正です。")
            }
            if let itemID = attachment.itemID, !itemIDs.contains(itemID) {
                throw TravelDataError.invalid("添付ファイルに関連付けられた予定が見つかりません。")
            }
        }
        for item in trip.checklist {
            try requireText(item.title, message: "チェックリストの項目名を入力してください。")
        }
    }

    static func validateAll(_ trips: [Trip]) throws {
        try requireUnique(trips.map(\.id))
        for trip in trips { try validate(trip) }
        let fileNames = trips.flatMap(\.attachments).map(\.fileName)
        guard Set(fileNames).count == fileNames.count else {
            throw TravelDataError.invalid("複数の旅行で同じ添付ファイルが共有されています。")
        }
    }

    private static func requireText(_ text: String, message: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TravelDataError.invalid(message)
        }
    }

    private static func requireUnique(_ ids: [UUID]) throws {
        guard Set(ids).count == ids.count else { throw TravelDataError.duplicateID }
    }
}

enum AttachmentFileName {
    static func validate(_ attachment: TravelAttachment) throws {
        let name = attachment.fileName
        let expected = "\(attachment.id.uuidString).\(attachment.kind.fileExtension)"
        guard name == expected else { throw TravelDataError.unsafeFileName }
    }
}

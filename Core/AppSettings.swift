import Foundation

public enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .system: return "端末の設定に合わせる"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
}

public enum DirectionsMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case transit, walking, driving

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .transit: return "公共交通機関"
        case .walking: return "徒歩"
        case .driving: return "車"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currencyCodes = ["JPY", "USD", "EUR", "GBP", "KRW", "CNY", "TWD", "THB", "AUD", "CAD", "CHF", "SGD"]
    public static let defaultChecklistTemplate = [
        "交通機関・宿泊の予約を確認", "チケットと予約書類を保存", "充電器・モバイルバッテリー",
        "身分証・パスポート", "天気と持ち物を確認"
    ]

    public var appearance: AppAppearance
    public var defaultCurrencyCode: String
    public var defaultTimeZoneIdentifier: String
    public var addsChecklistAutomatically: Bool
    public var checklistTemplate: [String]
    public var directionsMode: DirectionsMode
    public var includesReservationCodesInShare: Bool

    public init(appearance: AppAppearance = .system, defaultCurrencyCode: String = "JPY",
                defaultTimeZoneIdentifier: String = "Asia/Tokyo", addsChecklistAutomatically: Bool = true,
                checklistTemplate: [String] = AppSettings.defaultChecklistTemplate,
                directionsMode: DirectionsMode = .transit, includesReservationCodesInShare: Bool = false) {
        self.appearance = appearance
        self.defaultCurrencyCode = defaultCurrencyCode
        self.defaultTimeZoneIdentifier = defaultTimeZoneIdentifier
        self.addsChecklistAutomatically = addsChecklistAutomatically
        self.checklistTemplate = checklistTemplate
        self.directionsMode = directionsMode
        self.includesReservationCodesInShare = includesReservationCodesInShare
    }

    /// Returns the value that is safe to persist and apply to newly created trips.
    public func validated() throws -> AppSettings {
        guard Self.currencyCodes.contains(defaultCurrencyCode) else {
            throw TravelDataError.invalid("一覧から対応する通貨を選んでください。")
        }
        guard TimeZone(identifier: defaultTimeZoneIdentifier) != nil else {
            throw TravelDataError.invalid("タイムゾーンが不正です。")
        }
        guard checklistTemplate.count <= 100 else {
            throw TravelDataError.invalid("持ち物テンプレートは100項目以内にしてください。")
        }
        var result = self
        result.checklistTemplate = try checklistTemplate.map { entry in
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw TravelDataError.invalid("持ち物テンプレートに空の項目は保存できません。")
            }
            guard trimmed.count <= 200 else {
                throw TravelDataError.invalid("持ち物テンプレートの各項目は200文字以内にしてください。")
            }
            return trimmed
        }
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case appearance, defaultCurrencyCode, defaultTimeZoneIdentifier, addsChecklistAutomatically
        case checklistTemplate, directionsMode, includesReservationCodesInShare
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Missing keys can be settings introduced by a newer version; invalid
        // stored types or unknown enum values still fail instead of being reset.
        func value<T: Decodable>(_ type: T.Type, _ key: CodingKeys, default fallback: T) throws -> T {
            try values.contains(key) ? values.decode(type, forKey: key) : fallback
        }
        appearance = try value(AppAppearance.self, .appearance, default: .system)
        defaultCurrencyCode = try value(String.self, .defaultCurrencyCode, default: "JPY")
        defaultTimeZoneIdentifier = try value(String.self, .defaultTimeZoneIdentifier, default: "Asia/Tokyo")
        addsChecklistAutomatically = try value(Bool.self, .addsChecklistAutomatically, default: true)
        checklistTemplate = try value([String].self, .checklistTemplate, default: Self.defaultChecklistTemplate)
        directionsMode = try value(DirectionsMode.self, .directionsMode, default: .transit)
        includesReservationCodesInShare = try value(Bool.self, .includesReservationCodesInShare, default: false)
    }
}

public struct AppSettingsRepository: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("settings.json", isDirectory: false) }

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    public func load() throws -> AppSettings {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return AppSettings()
        }
        return try JSONDecoder().decode(AppSettings.self, from: data).validated()
    }

    public func save(_ settings: AppSettings) throws {
        let validated = try settings.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(validated)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

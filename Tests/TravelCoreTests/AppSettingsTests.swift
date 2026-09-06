import Foundation
import XCTest
@testable import TravelCore

final class AppSettingsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TabioriSettingsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testMissingSettingsUseJapaneseDefaultsWithoutCreatingFile() throws {
        let repository = AppSettingsRepository(directory: directory.appendingPathComponent("new"))
        let settings = try repository.load()
        XCTAssertEqual(settings, AppSettings())
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertEqual(settings.defaultCurrencyCode, "JPY")
        XCTAssertEqual(settings.defaultTimeZoneIdentifier, "Asia/Tokyo")
        XCTAssertTrue(settings.addsChecklistAutomatically)
        XCTAssertEqual(settings.checklistTemplate.count, 5)
        XCTAssertEqual(settings.directionsMode, .transit)
        XCTAssertFalse(settings.includesReservationCodesInShare)
        XCTAssertEqual(Set(AppSettings.currencyCodes).count, 12)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testAllSettingsRoundTripWithTrimmedChecklist() throws {
        let repository = AppSettingsRepository(directory: directory.appendingPathComponent("nested/data"))
        let draft = AppSettings(appearance: .dark, defaultCurrencyCode: "EUR",
            defaultTimeZoneIdentifier: "Europe/Paris", addsChecklistAutomatically: false,
            checklistTemplate: ["  パスポート \n", "\t充電器"], directionsMode: .walking,
            includesReservationCodesInShare: true)
        try repository.save(draft)
        let loaded = try repository.load()
        XCTAssertEqual(loaded, try draft.validated())
        XCTAssertEqual(loaded.checklistTemplate, ["パスポート", "充電器"])
        XCTAssertEqual(draft.checklistTemplate.first, "  パスポート \n")
    }

    func testCorruptSettingsThrowAndPreserveOriginalFile() throws {
        let repository = AppSettingsRepository(directory: directory)
        let corrupt = Data("{incomplete settings".utf8)
        try corrupt.write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
    }

    func testInvalidSaveLeavesPreviousSettingsIntact() throws {
        let repository = AppSettingsRepository(directory: directory)
        let original = AppSettings(appearance: .light, directionsMode: .driving)
        try repository.save(original)
        let bytes = try Data(contentsOf: repository.fileURL)
        var invalid = original
        invalid.defaultTimeZoneIdentifier = "Unknown/TimeZone"
        XCTAssertThrowsError(try repository.save(invalid))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), bytes)
        XCTAssertEqual(try repository.load(), original)
    }

    func testInvalidStoredValuesAndTypesAreRejected() throws {
        let repository = AppSettingsRepository(directory: directory)
        var invalid = AppSettings()
        invalid.defaultCurrencyCode = "XYZ"
        try JSONEncoder().encode(invalid).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        try Data("{\"appearance\":\"unknown\"}".utf8).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        try Data("{\"includesReservationCodesInShare\":\"yes\"}".utf8).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        try Data("{\"defaultCurrencyCode\":null}".utf8).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
    }

    func testNewSettingsFieldsUseDefaultsWhenOlderDataOmitsThem() throws {
        let repository = AppSettingsRepository(directory: directory)
        try Data("{\"appearance\":\"dark\",\"defaultCurrencyCode\":\"USD\"}".utf8).write(to: repository.fileURL)
        let loaded = try repository.load()
        XCTAssertEqual(loaded.appearance, .dark)
        XCTAssertEqual(loaded.defaultCurrencyCode, "USD")
        XCTAssertEqual(loaded.directionsMode, .transit)
        XCTAssertFalse(loaded.includesReservationCodesInShare)
    }

    func testChecklistAllowsEmptyAndBoundaryValuesButRejectsInvalidEntries() throws {
        XCTAssertNoThrow(try AppSettings(checklistTemplate: []).validated())
        XCTAssertNoThrow(try AppSettings(checklistTemplate: Array(repeating: String(repeating: "あ", count: 200), count: 100)).validated())
        XCTAssertThrowsError(try AppSettings(checklistTemplate: Array(repeating: "項目", count: 101)).validated())
        XCTAssertThrowsError(try AppSettings(checklistTemplate: [String(repeating: "あ", count: 201)]).validated())
        XCTAssertThrowsError(try AppSettings(checklistTemplate: [" \n\t"]).validated())
    }

    func testCurrencyAndTimeZoneMustBeSupported() throws {
        for currency in AppSettings.currencyCodes {
            XCTAssertNoThrow(try AppSettings(defaultCurrencyCode: currency).validated())
        }
        XCTAssertThrowsError(try AppSettings(defaultCurrencyCode: "BTC").validated())
        XCTAssertThrowsError(try AppSettings(defaultTimeZoneIdentifier: "").validated())
        XCTAssertNoThrow(try AppSettings(defaultTimeZoneIdentifier: "America/New_York").validated())
    }

    func testReservationCodeSharingCanBeDisabledWithoutChangingNotes() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let trip = Trip(title: "旅", startDate: start, endDate: start,
            notes: "集合場所は改札前", items: [ItineraryItem(title: "京都へ", kind: .train, startDate: start,
                serviceNumber: "のぞみ", reservationCode: "SECRET-123", notes: "メモに書いた番号: NOTE-456")])
        let privateExport = TripExport.text(for: trip, includeReservationCodes: false)
        XCTAssertFalse(privateExport.contains("SECRET-123"))
        XCTAssertFalse(privateExport.contains("予約番号:"))
        XCTAssertTrue(privateExport.contains("便・列車番号: のぞみ"))
        XCTAssertTrue(privateExport.contains("メモに書いた番号: NOTE-456"))
        XCTAssertTrue(privateExport.contains("集合場所は改札前"))
        XCTAssertTrue(TripExport.text(for: trip).contains("予約番号: SECRET-123"))
        XCTAssertTrue(TripExport.text(for: trip, includeReservationCodes: true).contains("予約番号: SECRET-123"))
        XCTAssertEqual(trip.items.first?.reservationCode, "SECRET-123")
    }
}

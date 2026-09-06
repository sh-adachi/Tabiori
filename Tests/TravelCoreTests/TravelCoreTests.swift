import Foundation
import XCTest
@testable import TravelCore

final class TravelCoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TabioriCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func makeTrip() -> Trip {
        Trip(title: "京都の旅", destination: "京都", startDate: date("2026-10-01T00:00:00Z"),
             endDate: date("2026-10-03T00:00:00Z"), createdAt: date("2026-09-01T00:00:00Z"))
    }

    private func makeItem() -> ItineraryItem {
        ItineraryItem(title: "京都へ", kind: .train, startDate: date("2026-10-01T01:00:00Z"))
    }

    func testMissingRepositoryStartsEmpty() throws {
        let repository = TravelRepository(directory: temporaryDirectory.appendingPathComponent("new"))
        XCTAssertEqual(try repository.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testPersistenceRoundTripPreservesAllNestedFields() throws {
        let repository = TravelRepository(directory: temporaryDirectory.appendingPathComponent("nested/data"))
        var trip = makeTrip()
        let item = ItineraryItem(title: "夕食", kind: .restaurant,
            startDate: date("2026-10-02T09:00:00Z"), endDate: date("2026-10-02T10:00:00Z"),
            departure: "宿", arrival: "お店", serviceNumber: "番号", reservationCode: "TEST-123",
            notes: "窓側の席\nアレルギーを伝える", cost: 3500.5,
            location: Place(name: "お店", address: "京都市", latitude: 35, longitude: 135), isCompleted: true)
        let attachmentID = UUID()
        trip.items = [item]
        trip.attachments = [TravelAttachment(id: attachmentID, displayName: "予約書.pdf",
            fileName: "\(attachmentID.uuidString).pdf", kind: .pdf,
            createdAt: date("2026-09-01T00:00:00Z"), itemID: item.id)]
        trip.checklist = [ChecklistItem(title: "充電器", isChecked: true)]
        trip.budget = 30000
        trip.notes = "集合場所は改札前"
        try repository.save([trip])
        XCTAssertEqual(try repository.load(), [trip])
        try repository.save([])
        XCTAssertEqual(try repository.load(), [])
    }

    func testInvalidSavePreservesExistingDocument() throws {
        let repository = TravelRepository(directory: temporaryDirectory)
        let trip = makeTrip()
        try repository.save([trip])
        let original = try Data(contentsOf: repository.fileURL)
        var invalidTrip = trip
        invalidTrip.budget = -1
        XCTAssertThrowsError(try repository.save([invalidTrip]))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
        XCTAssertEqual(try repository.load(), [trip])
    }

    func testUnreadableJSONThrowsWithoutChangingFile() throws {
        let repository = TravelRepository(directory: temporaryDirectory)
        let broken = Data("{broken json".utf8)
        try broken.write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), broken)
    }

    func testLoadRejectsSemanticallyInvalidData() throws {
        let repository = TravelRepository(directory: temporaryDirectory)
        var trip = makeTrip()
        trip.title = "  \n"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode([trip]).write(to: repository.fileURL)
        XCTAssertThrowsError(try repository.load())
    }

    func testRepositoryRejectsDuplicateTripIDs() throws {
        let repository = TravelRepository(directory: temporaryDirectory)
        let trip = makeTrip()
        XCTAssertThrowsError(try repository.save([trip, trip]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }

    func testValidationUsesWholeTravelDaysInDestinationTimeZone() throws {
        var trip = makeTrip()
        trip.startDate = date("2026-10-01T14:00:00Z") // October 1, 23:00 in Tokyo.
        trip.endDate = date("2026-10-02T00:00:00Z")
        var item = makeItem()
        item.startDate = date("2026-09-30T15:00:00Z") // October 1, 00:00 in Tokyo.
        item.endDate = date("2026-10-02T14:59:59Z")
        trip.items = [item]
        XCTAssertNoThrow(try TripValidator.validate(trip))
        trip.items[0].endDate = date("2026-10-02T15:00:00Z")
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip.items[0].endDate = nil
        trip.items[0].startDate = date("2026-09-30T14:59:59Z")
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testSameDayTravelDoesNotDependOnHiddenTimeComponents() throws {
        var trip = makeTrip()
        trip.startDate = date("2026-10-01T12:00:00Z")
        trip.endDate = date("2026-10-01T00:00:00Z")
        XCTAssertNoThrow(try TripValidator.validate(trip))
        trip.endDate = date("2026-09-30T00:00:00Z")
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testDaylightSavingDayUsesCalendarBoundary() throws {
        var trip = makeTrip()
        trip.timeZoneIdentifier = "America/New_York"
        trip.startDate = date("2026-03-08T05:00:00Z")
        trip.endDate = trip.startDate
        trip.items = [ItineraryItem(title: "夜の散歩", startDate: date("2026-03-09T03:59:59Z"))]
        XCTAssertNoThrow(try TripValidator.validate(trip))
        trip.items[0].startDate = date("2026-03-09T04:00:00Z")
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testValidationRejectsLongTrips() throws {
        var trip = makeTrip()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone
        trip.endDate = calendar.date(byAdding: .day, value: 365, to: trip.startDate)!
        XCTAssertNoThrow(try TripValidator.validate(trip))
        trip.endDate = calendar.date(byAdding: .day, value: 366, to: trip.startDate)!
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testValidationRejectsInvalidDatesAndTimeZone() throws {
        var trip = makeTrip()
        trip.timeZoneIdentifier = "invalid/timezone"
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip = makeTrip()
        trip.startDate = Date(timeIntervalSince1970: .infinity)
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip = makeTrip()
        trip.items = [makeItem()]
        trip.items[0].endDate = trip.items[0].startDate.addingTimeInterval(-1)
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testValidationRejectsNegativeAndNonfiniteMoney() throws {
        for amount in [-1, Double.nan, Double.infinity, -Double.infinity] {
            var trip = makeTrip()
            trip.budget = amount
            XCTAssertThrowsError(try TripValidator.validate(trip))
            trip.budget = 0
            trip.items = [makeItem()]
            trip.items[0].cost = amount
            XCTAssertThrowsError(try TripValidator.validate(trip))
        }
        var trip = makeTrip()
        var first = makeItem()
        first.cost = Double.greatestFiniteMagnitude
        var second = makeItem()
        second.cost = Double.greatestFiniteMagnitude
        trip.items = [first, second]
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testValidationRejectsInvalidCoordinatesAndAcceptsBoundaries() throws {
        var trip = makeTrip()
        trip.items = [makeItem()]
        for place in [Place(latitude: 90.1, longitude: 0), Place(latitude: 0, longitude: -180.1),
                      Place(latitude: .nan, longitude: 0), Place(latitude: 0, longitude: .infinity)] {
            trip.items[0].location = place
            XCTAssertThrowsError(try TripValidator.validate(trip))
        }
        trip.items[0].location = Place(latitude: -90, longitude: 180)
        XCTAssertNoThrow(try TripValidator.validate(trip))
    }

    func testValidationRejectsDuplicateNestedIDsAndDanglingAttachmentLinks() throws {
        var trip = makeTrip()
        let item = makeItem()
        trip.items = [item, item]
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip.items = [item]
        let check = ChecklistItem(title: "荷物")
        trip.checklist = [check, check]
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip.checklist = [check]
        let id = UUID()
        var attachment = TravelAttachment(id: id, displayName: "予約.pdf", fileName: "\(id.uuidString).pdf",
                                          kind: .pdf, itemID: UUID())
        trip.attachments = [attachment]
        XCTAssertThrowsError(try TripValidator.validate(trip))
        attachment.itemID = item.id
        trip.attachments = [attachment]
        XCTAssertNoThrow(try TripValidator.validate(trip))
        trip.attachments = [attachment, attachment]
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testValidationRejectsBlankTitles() throws {
        var trip = makeTrip()
        trip.title = " \n"
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip = makeTrip()
        trip.items = [ItineraryItem(title: " ", startDate: trip.startDate)]
        XCTAssertThrowsError(try TripValidator.validate(trip))
        trip.items = []
        trip.checklist = [ChecklistItem(title: "\t")]
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testAttachmentsRoundTripWithSafeGeneratedFileName() throws {
        let repository = AttachmentRepository(directory: temporaryDirectory.appendingPathComponent("attachments"))
        let content = Data("%PDF-1.7\nexample".utf8)
        let itemID = UUID()
        let attachment = try repository.store(data: content, displayName: "../../予約.pdf", kind: .pdf, itemID: itemID)
        XCTAssertEqual(attachment.itemID, itemID)
        XCTAssertEqual(attachment.displayName, "../../予約.pdf")
        XCTAssertEqual(attachment.fileName, "\(attachment.id.uuidString).pdf")
        let url = try repository.url(for: attachment)
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path, repository.directory.path)
        XCTAssertEqual(try Data(contentsOf: url), content)
        try repository.remove(attachment)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNoThrow(try repository.remove(attachment))
        XCTAssertThrowsError(try repository.url(for: attachment))
    }

    func testAttachmentLimitIncludesExactMaximumAndRejectsEmpty() throws {
        let repository = AttachmentRepository(directory: temporaryDirectory)
        XCTAssertThrowsError(try repository.store(data: Data(), displayName: "empty.pdf", kind: .pdf)) { error in
            XCTAssertEqual(error as? TravelDataError, .emptyAttachment)
        }
        let data = Data(repeating: 0, count: AttachmentRepository.maximumFileSize)
        let attachment = try repository.store(data: data, displayName: "large.jpg", kind: .photo)
        XCTAssertEqual(try Data(contentsOf: repository.url(for: attachment)).count, data.count)
        var oversized = data
        oversized.append(0)
        XCTAssertThrowsError(try repository.store(data: oversized, displayName: "too-large.jpg", kind: .photo)) { error in
            XCTAssertEqual(error as? TravelDataError, .attachmentTooLarge)
        }
    }

    func testAttachmentPathTraversalAndTypeMismatchAreRejected() throws {
        let repository = AttachmentRepository(directory: temporaryDirectory)
        var attachment = TravelAttachment(displayName: "attack", fileName: "../trips.json", kind: .pdf)
        XCTAssertThrowsError(try repository.url(for: attachment))
        XCTAssertThrowsError(try repository.remove(attachment))
        attachment.fileName = "\(attachment.id.uuidString).jpg"
        XCTAssertThrowsError(try repository.url(for: attachment))
        var trip = makeTrip()
        trip.attachments = [attachment]
        XCTAssertThrowsError(try TripValidator.validate(trip))
    }

    func testAttachmentSymlinkCannotReadOrDeleteOutsideFile() throws {
        let directory = temporaryDirectory.appendingPathComponent("attachments")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = temporaryDirectory.appendingPathComponent("private.txt")
        try Data("private".utf8).write(to: target)
        let id = UUID()
        let attachment = TravelAttachment(id: id, displayName: "file.pdf", fileName: "\(id.uuidString).pdf", kind: .pdf)
        let link = directory.appendingPathComponent(attachment.fileName)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let repository = AttachmentRepository(directory: directory)
        XCTAssertThrowsError(try repository.url(for: attachment))
        XCTAssertThrowsError(try repository.remove(attachment))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "private")
    }

    func testSameDisplayNameKeepsSeparateAttachmentFiles() throws {
        let repository = AttachmentRepository(directory: temporaryDirectory)
        let first = try repository.store(data: Data([1]), displayName: "予約.pdf", kind: .pdf)
        let second = try repository.store(data: Data([2]), displayName: "予約.pdf", kind: .pdf)
        XCTAssertNotEqual(first.fileName, second.fileName)
        XCTAssertEqual(try Data(contentsOf: repository.url(for: first)), Data([1]))
        XCTAssertEqual(try Data(contentsOf: repository.url(for: second)), Data([2]))
    }

    func testRepositoryRejectsAttachmentSharedAcrossTrips() throws {
        let repository = TravelRepository(directory: temporaryDirectory)
        var first = makeTrip()
        var second = makeTrip()
        let id = UUID()
        let attachment = TravelAttachment(id: id, displayName: "予約.pdf", fileName: "\(id.uuidString).pdf", kind: .pdf)
        first.attachments = [attachment]
        second.attachments = [attachment]
        XCTAssertThrowsError(try repository.save([first, second]))
    }

    func testExportIsOrderedAndUsesTripTimeZone() throws {
        var trip = makeTrip()
        trip.budget = 10000
        trip.notes = "旅のメモです"
        var early = makeItem()
        early.title = "朝の移動"
        early.startDate = date("2026-10-01T00:00:00Z")
        early.departure = "東京"
        early.arrival = "京都"
        early.serviceNumber = "のぞみ1"
        early.reservationCode = "EXAMPLE"
        early.location = Place(name: "京都駅", address: "京都市", latitude: 34.98, longitude: 135.75)
        early.cost = 1500
        early.isCompleted = true
        var late = makeItem()
        late.title = "夜の食事"
        late.startDate = date("2026-10-01T10:00:00Z")
        late.cost = 2000
        trip.items = [late, early]
        trip.checklist = [ChecklistItem(title: "充電器", isChecked: true), ChecklistItem(title: "傘")]
        let id = UUID()
        trip.attachments = [TravelAttachment(id: id, displayName: "予約.pdf", fileName: "\(id.uuidString).pdf", kind: .pdf)]
        let text = TripExport.text(for: trip)
        XCTAssertTrue(text.contains("09:00 [電車] 朝の移動"))
        XCTAssertTrue(text.contains("東京 → 京都"))
        XCTAssertTrue(text.contains("予約番号: EXAMPLE"))
        XCTAssertTrue(text.contains("地図: https://maps.apple.com/?ll=34.98,135.75"))
        XCTAssertTrue(text.contains("☑ 充電器"))
        XCTAssertTrue(text.contains("☐ 傘"))
        XCTAssertTrue(text.contains("添付ファイル（ファイル本体は別途共有してください）"))
        XCTAssertFalse(text.contains(id.uuidString))
        XCTAssertLessThan(text.range(of: "朝の移動")!.lowerBound, text.range(of: "夜の食事")!.lowerBound)
        XCTAssertEqual(trip.totalCost, 3500)
    }

    func testOvernightExportShowsEndCalendarDay() throws {
        var trip = makeTrip()
        trip.items = [ItineraryItem(title: "夜行バス", kind: .bus,
            startDate: date("2026-10-01T14:00:00Z"), endDate: date("2026-10-01T22:00:00Z"))]
        let text = TripExport.text(for: trip)
        XCTAssertTrue(text.contains("23:00–2026年10月2日(金) 07:00"))
    }

    func testSampleIsExplicitlyFictionalValidAndInFuture() throws {
        let now = date("2026-12-25T20:00:00Z")
        let trip = SampleData.makeTrip(now: now)
        try TripValidator.validate(trip)
        XCTAssertGreaterThan(trip.startDate, now)
        XCTAssertEqual(trip.title, "京都、余白を楽しむ旅")
        XCTAssertTrue(trip.notes.contains("サンプル"))
        XCTAssertTrue(trip.notes.contains("架空"))
        XCTAssertTrue(trip.items.contains { $0.kind == .train })
        XCTAssertTrue(trip.items.contains { $0.kind == .bus })
        XCTAssertTrue(trip.items.contains { $0.kind == .restaurant })
        XCTAssertTrue(trip.items.contains { $0.location != nil })
        XCTAssertTrue(trip.checklist.contains { $0.title == "充電器" })
        XCTAssertTrue(trip.attachments.isEmpty)
        XCTAssertNotEqual(SampleData.makeTrip(now: now).id, trip.id)
    }
}

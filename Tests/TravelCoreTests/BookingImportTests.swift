import Foundation
import XCTest
@testable import TravelCore

final class BookingImportTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func makeTrip() -> Trip {
        let attachmentID = UUID()
        return Trip(
            title: "京都の旅", destination: "京都", startDate: date("2026-10-01T00:00:00Z"),
            endDate: date("2026-10-03T00:00:00Z"), budget: 50000, notes: "集合場所は改札前",
            items: [ItineraryItem(title: "夕食", kind: .restaurant, startDate: date("2026-10-02T09:00:00Z"),
                                  reservationCode: "DINNER-1", notes: "窓側の席", cost: 3500,
                                  location: Place(name: "お店", address: "京都市", latitude: 35, longitude: 135),
                                  isCompleted: true)],
            attachments: [TravelAttachment(id: attachmentID, displayName: "予約.jpg",
                                           fileName: "\(attachmentID.uuidString).jpg", kind: .photo)],
            checklist: [ChecklistItem(title: "充電器", isChecked: true)]
        )
    }

    private func candidate(title: String = "京都へ", start: String = "2026-10-01T01:00:00Z") -> BookingCandidate {
        BookingCandidate(title: title, kind: .train, startDate: date(start),
                         departure: "東京", arrival: "京都", serviceNumber: "のぞみ 101", reservationCode: "BOOK-123")
    }

    private func applying(_ candidates: [BookingCandidate], to trip: Trip, expand: Bool = false,
                          destination: String? = nil) throws -> Trip {
        try BookingImport.applying(candidates, sourceAttachmentID: trip.attachments[0].id,
                                   destination: destination, expandTripDates: expand, to: trip)
    }

    func testAddsOnlySelectedPlansWithOneSourceAndPreservesExistingState() throws {
        let trip = makeTrip()
        let outward = candidate()
        let hotel = BookingCandidate(title: "京都のホテル", kind: .hotel, startDate: date("2026-10-01T06:00:00Z"),
                                     endDate: date("2026-10-03T01:00:00Z"), notes: "宿泊料金 20000 円",
                                     placeName: "  京都のホテル  ", placeAddress: "京都市下京区")
        let ignored = BookingCandidate(title: "日付を読めなかった予定", isSelected: false)
        let result = try applying([outward, hotel, ignored], to: trip)

        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items[0], trip.items[0])
        XCTAssertEqual(result.items.map(\.id), [trip.items[0].id, outward.id, hotel.id])
        XCTAssertEqual(result.items[1].sourceAttachmentID, trip.attachments[0].id)
        XCTAssertEqual(result.items[2].sourceAttachmentID, trip.attachments[0].id)
        XCTAssertEqual(result.attachments, trip.attachments)
        XCTAssertEqual(result.checklist, trip.checklist)
        XCTAssertEqual(result.title, trip.title)
        XCTAssertEqual(result.destination, trip.destination)
        XCTAssertEqual(result.startDate, trip.startDate)
        XCTAssertEqual(result.endDate, trip.endDate)
        XCTAssertEqual(result.notes, trip.notes)
        XCTAssertEqual(result.budget, trip.budget)
        XCTAssertEqual(result.currencyCode, trip.currencyCode)
        XCTAssertEqual(result.timeZoneIdentifier, trip.timeZoneIdentifier)
        XCTAssertEqual(result.createdAt, trip.createdAt)
        XCTAssertEqual(result.items[2].notes, "宿泊料金 20000 円\n場所：京都のホテル\n住所：京都市下京区")
        XCTAssertNil(result.items[2].location)
        XCTAssertEqual(result.items[2].cost, 0)
        XCTAssertFalse(result.items[2].isCompleted)
    }

    func testSourceImageDeletionRequiresClearingLinksAndKeepsPlans() throws {
        var trip = try applying([candidate()], to: makeTrip())
        let savedItems = trip.items
        trip.attachments.removeAll()
        XCTAssertThrowsError(try TripValidator.validate(trip))
        for index in trip.items.indices { trip.items[index].sourceAttachmentID = nil }
        XCTAssertNoThrow(try TripValidator.validate(trip))
        XCTAssertEqual(trip.items.map(\.id), savedItems.map(\.id))
        XCTAssertEqual(trip.items.map(\.title), savedItems.map(\.title))
    }

    func testMissingRequiredFieldsNeedReviewAndWarningsRemainAdvisory() throws {
        let trip = makeTrip()
        var plan = BookingCandidate(title: "宿泊", warnings: ["チェックイン日時を確認してください。"])
        XCTAssertNil(plan.startDate)
        XCTAssertThrowsError(try applying([plan], to: trip))
        plan.startDate = date("2026-10-01T06:00:00Z")
        plan.title = " \n "
        XCTAssertThrowsError(try applying([plan], to: trip))
        plan.title = "  宿泊  "
        let result = try applying([plan], to: trip)
        XCTAssertEqual(result.items.last?.title, "宿泊")
        XCTAssertEqual(result.items.last?.startDate, plan.startDate)
        XCTAssertNil(result.items.last?.endDate)
    }

    func testRejectsEmptySelectionAndMissingSource() throws {
        let trip = makeTrip()
        XCTAssertThrowsError(try applying([], to: trip))
        XCTAssertThrowsError(try applying([BookingCandidate(isSelected: false)], to: trip))
        XCTAssertThrowsError(try BookingImport.applying([candidate()], sourceAttachmentID: UUID(),
                                                       destination: nil, expandTripDates: false, to: trip)) { error in
            XCTAssertEqual(error as? TravelDataError, .attachmentMissing)
        }
    }

    func testRejectsInvalidDatesAndReversedEndWithoutChangingTrip() throws {
        let trip = makeTrip()
        let original = trip
        var plan = candidate()
        plan.startDate = Date(timeIntervalSince1970: .infinity)
        XCTAssertThrowsError(try applying([plan], to: trip, expand: true))
        plan = candidate()
        plan.endDate = Date(timeIntervalSince1970: .nan)
        XCTAssertThrowsError(try applying([plan], to: trip, expand: true))
        plan.endDate = date("2026-10-01T00:00:00Z")
        XCTAssertThrowsError(try applying([candidate(title: "有効な予定"), plan], to: trip, expand: true))
        XCTAssertEqual(trip, original)
    }

    func testDetectsNormalizedTitleDuplicateAndRepeatedCandidateID() throws {
        let trip = makeTrip()
        let plan = candidate(title: "TOKYO  Express")
        let imported = try applying([plan], to: trip)
        let duplicate = candidate(title: "  ｔｏｋｙｏ\n EXPRESS ")
        XCTAssertEqual(BookingImport.duplicate(of: duplicate, in: imported)?.id, plan.id)
        XCTAssertThrowsError(try applying([duplicate], to: imported))
        XCTAssertThrowsError(try applying([plan], to: imported)) { error in
            XCTAssertEqual(error as? TravelDataError, .duplicateID)
        }
    }

    func testServiceOrReservationWithSameDateAndRouteDetectsRenamedPlan() throws {
        let trip = makeTrip()
        let plan = candidate()
        let imported = try applying([plan], to: trip)
        var renamed = candidate(title: "東海道新幹線の予約")
        renamed.serviceNumber = " のぞみ １０１ "
        renamed.reservationCode = "別の番号"
        XCTAssertEqual(BookingImport.duplicate(of: renamed, in: imported)?.id, plan.id)
        renamed.serviceNumber = ""
        renamed.reservationCode = " book-123 "
        XCTAssertEqual(BookingImport.duplicate(of: renamed, in: imported)?.id, plan.id)
    }

    func testSharedReservationDoesNotMergeReturnJourneyOrDifferentKind() throws {
        let trip = makeTrip()
        let outward = candidate()
        let imported = try applying([outward], to: trip)
        var returning = candidate(title: "東京へ", start: "2026-10-03T01:00:00Z")
        returning.departure = "京都"
        returning.arrival = "東京"
        returning.serviceNumber = "のぞみ 102"
        XCTAssertNil(BookingImport.duplicate(of: returning, in: imported))
        XCTAssertEqual(try applying([returning], to: imported).items.count, 3)

        returning.startDate = outward.startDate
        XCTAssertNil(BookingImport.duplicate(of: returning, in: imported))
        var hotel = outward
        hotel.id = UUID()
        hotel.kind = .hotel
        XCTAssertNil(BookingImport.duplicate(of: hotel, in: imported))
    }

    func testRejectsDuplicatesWithinSelectedBatch() throws {
        let trip = makeTrip()
        let plan = candidate()
        XCTAssertThrowsError(try applying([plan, plan], to: trip)) { error in
            XCTAssertEqual(error as? TravelDataError, .duplicateID)
        }
        XCTAssertThrowsError(try applying([plan, candidate()], to: trip))
        var unselectedDuplicate = candidate()
        unselectedDuplicate.isSelected = false
        XCTAssertEqual(try applying([plan, unselectedDuplicate], to: trip).items.count, 2)
    }

    func testTravelDatesExpandOnlyWhenExplicitlyRequestedInTripTimeZone() throws {
        let trip = makeTrip()
        var early = candidate(start: "2026-09-30T14:30:00Z") // September 30, 23:30 in Tokyo.
        early.endDate = date("2026-10-03T15:00:00Z") // October 4, 00:00 in Tokyo.
        XCTAssertThrowsError(try applying([early], to: trip))
        let expanded = try applying([early], to: trip, expand: true)
        XCTAssertEqual(expanded.startDate, date("2026-09-29T15:00:00Z"))
        XCTAssertEqual(expanded.endDate, date("2026-10-03T15:00:00Z"))
        XCTAssertEqual(expanded.items[0], trip.items[0])
        XCTAssertEqual(expanded.items.last?.startDate, early.startDate)
        XCTAssertEqual(expanded.items.last?.endDate, early.endDate)
    }

    func testExpansionPreservesExistingBoundsForDatesAlreadyInsideTheirTravelDays() throws {
        var trip = makeTrip()
        trip.startDate = date("2026-10-01T05:00:00Z")
        trip.endDate = date("2026-10-03T00:00:00Z")
        var plan = candidate()
        plan.endDate = date("2026-10-03T14:59:59Z")
        let result = try applying([plan], to: trip, expand: true)
        XCTAssertEqual(result.startDate, trip.startDate)
        XCTAssertEqual(result.endDate, trip.endDate)
    }

    func testExpansionCannotExceedMaximumTripDuration() throws {
        let trip = makeTrip()
        let distant = candidate(start: "2027-10-02T01:00:00Z")
        XCTAssertThrowsError(try applying([distant], to: trip, expand: true))
    }

    func testDestinationChangesOnlyWithNonemptyExplicitValue() throws {
        let trip = makeTrip()
        XCTAssertEqual(try applying([candidate()], to: trip).destination, "京都")
        XCTAssertEqual(try applying([candidate()], to: trip, destination: " \n ").destination, "京都")
        XCTAssertEqual(try applying([candidate()], to: trip, destination: " 大阪 ").destination, "大阪")
    }

    func testOldItemJSONDecodesAndNewSourceLinkRoundTrips() throws {
        let trip = makeTrip()
        let imported = try applying([candidate()], to: trip)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(Trip.self, from: encoder.encode(imported)), imported)

        let item = try XCTUnwrap(imported.items.last)
        var oldJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(item)) as? [String: Any])
        XCTAssertNotNil(oldJSON.removeValue(forKey: "sourceAttachmentID"))
        let oldData = try JSONSerialization.data(withJSONObject: oldJSON)
        let decoded = try decoder.decode(ItineraryItem.self, from: oldData)
        XCTAssertNil(decoded.sourceAttachmentID)
        var expected = item
        expected.sourceAttachmentID = nil
        XCTAssertEqual(decoded, expected)
    }
}

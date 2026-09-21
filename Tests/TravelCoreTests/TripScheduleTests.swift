import Foundation
import XCTest
@testable import TravelCore

final class TripScheduleTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func trip(items: [ItineraryItem] = []) -> Trip {
        Trip(title: "東京の旅", startDate: date("2026-10-01T08:00:00Z"),
             endDate: date("2026-10-03T01:00:00Z"), items: items)
    }

    private func item(_ title: String, start: String, end: String? = nil,
                      completed: Bool = false, id: UUID = UUID()) -> ItineraryItem {
        ItineraryItem(id: id, title: title, startDate: date(start),
                      endDate: end.map(date), isCompleted: completed)
    }

    func testTodayUsesDestinationCalendarAndWholeFirstAndLastDays() {
        let schedule = TripSchedule(trip: trip())
        XCTAssertEqual(schedule.calendar.timeZone.identifier, "Asia/Tokyo")
        XCTAssertNil(schedule.today(at: date("2026-09-30T14:59:59Z")))
        XCTAssertEqual(schedule.today(at: date("2026-09-30T15:00:00Z")),
                       date("2026-09-30T15:00:00Z"))
        XCTAssertEqual(schedule.today(at: date("2026-10-03T14:59:59Z")),
                       date("2026-10-02T15:00:00Z"))
        XCTAssertNil(schedule.today(at: date("2026-10-03T15:00:00Z")))
    }

    func testInitialSelectionUsesTodayForActiveTripAndFirstDayOtherwise() {
        let schedule = TripSchedule(trip: trip())
        XCTAssertEqual(schedule.selectedDay(nil, at: date("2026-10-01T17:00:00Z")),
                       date("2026-10-01T15:00:00Z"))
        for now in ["2026-09-01T00:00:00Z", "2026-11-01T00:00:00Z"] {
            XCTAssertEqual(schedule.selectedDay(nil, at: date(now)),
                           date("2026-09-30T15:00:00Z"))
        }
    }

    func testExplicitDaySelectionIsPreservedWhileTripIsActiveOrOutsideTrip() {
        let schedule = TripSchedule(trip: trip())
        let selected = date("2026-10-02T15:00:00Z")
        for now in ["2026-09-01T00:00:00Z", "2026-10-01T00:00:00Z", "2026-11-01T00:00:00Z"] {
            XCTAssertEqual(schedule.selectedDay(selected, at: date(now)), selected)
        }
    }

    func testRemovedDayAndChangedTimeZoneInvalidateSelection() {
        var draft = trip()
        draft.endDate = date("2026-10-02T01:00:00Z")
        let now = date("2026-10-01T17:00:00Z")
        XCTAssertEqual(TripSchedule(trip: draft).selectedDay(date("2026-10-02T15:00:00Z"), at: now),
                       date("2026-10-01T15:00:00Z"))
        draft.timeZoneIdentifier = "America/Los_Angeles"
        XCTAssertEqual(TripSchedule(trip: draft).selectedDay(date("2026-09-30T15:00:00Z"), at: now),
                       date("2026-10-01T07:00:00Z"))
    }

    func testNonMidnightSelectionFallsBackToToday() {
        let schedule = TripSchedule(trip: trip())
        XCTAssertEqual(schedule.selectedDay(date("2026-10-01T08:00:00Z"),
                                            at: date("2026-10-02T05:00:00Z")),
                       date("2026-10-01T15:00:00Z"))
    }

    func testDaysAndTodayFollowSpringAndAutumnDaylightSavingBoundaries() {
        let transitions = [
            ("2026-03-07T12:00:00Z", "2026-03-09T12:00:00Z",
             ["2026-03-07T05:00:00Z", "2026-03-08T05:00:00Z", "2026-03-09T04:00:00Z"]),
            ("2026-10-31T12:00:00Z", "2026-11-02T12:00:00Z",
             ["2026-10-31T04:00:00Z", "2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z"])
        ]
        for (start, end, expected) in transitions {
            let schedule = TripSchedule(trip: Trip(title: "NY", startDate: date(start), endDate: date(end),
                                                  timeZoneIdentifier: "America/New_York"))
            XCTAssertEqual(schedule.days, expected.map(date))
            let finalDay = date(expected.last!)
            XCTAssertEqual(schedule.today(at: finalDay), finalDay)
            XCTAssertEqual(schedule.today(at: finalDay.addingTimeInterval(-1)), date(expected[1]))
        }
    }

    func testMalformedDraftEnumerationIsBoundedAndEmptyDraftHasFallback() {
        var draft = trip()
        draft.endDate = date("2030-01-01T00:00:00Z")
        XCTAssertEqual(TripSchedule(trip: draft).days.count, 367)
        draft.endDate = date("2026-09-01T00:00:00Z")
        let schedule = TripSchedule(trip: draft)
        XCTAssertTrue(schedule.days.isEmpty)
        XCTAssertNil(schedule.today(at: draft.startDate))
        XCTAssertEqual(schedule.selectedDay(nil, at: draft.startDate), draft.startDate)
    }

    func testFocusIsHiddenBeforeAndAfterTrip() {
        let schedule = TripSchedule(trip: trip(items: [
            item("予定", start: "2026-10-01T00:00:00Z", end: "2026-10-02T00:00:00Z")
        ]))
        XCTAssertNil(schedule.focus(at: date("2026-09-30T14:59:59Z")))
        XCTAssertNil(schedule.focus(at: date("2026-10-03T15:00:00Z")))
    }

    func testFocusPrefersOngoingOverUpcomingAndExcludesCompletedItems() {
        let ongoing = item("現在の予定", start: "2026-10-01T01:00:00Z", end: "2026-10-01T03:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [
            item("次の予定", start: "2026-10-01T02:00:00Z"),
            item("完了済み", start: "2026-10-01T01:30:00Z", end: "2026-10-01T03:00:00Z", completed: true),
            ongoing
        ]))
        let focus = schedule.focus(at: date("2026-10-01T02:00:00Z"))
        XCTAssertEqual(focus?.item.id, ongoing.id)
        XCTAssertEqual(focus?.isOngoing, true)
    }

    func testFocusAdvancesAtEndBoundaryAndIncludesStartBoundary() {
        let first = item("最初の予定", start: "2026-10-01T01:00:00Z", end: "2026-10-01T02:00:00Z")
        let next = item("次の予定", start: "2026-10-01T02:00:00Z", end: "2026-10-01T03:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [next, first]))
        XCTAssertEqual(schedule.focus(at: first.startDate)?.item.id, first.id)
        XCTAssertEqual(schedule.focus(at: first.startDate)?.isOngoing, true)
        XCTAssertEqual(schedule.focus(at: next.startDate)?.item.id, next.id)
        XCTAssertEqual(schedule.focus(at: next.startDate)?.isOngoing, true)
        XCTAssertNil(schedule.focus(at: next.endDate!))
    }

    func testExpiredAndCompletedItemsAreSkippedForNextDayUpcomingItem() {
        let next = item("明日の予定", start: "2026-10-02T01:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [
            next,
            item("終了済み", start: "2026-10-01T01:00:00Z", end: "2026-10-01T02:00:00Z"),
            item("終了なしの過去予定", start: "2026-10-01T02:00:00Z"),
            item("完了済みの未来予定", start: "2026-10-01T04:00:00Z", completed: true)
        ]))
        let focus = schedule.focus(at: date("2026-10-01T03:00:00Z"))
        XCTAssertEqual(focus?.item.id, next.id)
        XCTAssertEqual(focus?.isOngoing, false)
    }

    func testItemWithoutEndIsUpcomingExactlyAtStartAndSkippedAfterward() {
        let point = item("集合", start: "2026-10-01T01:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [point]))
        XCTAssertEqual(schedule.focus(at: point.startDate)?.item.id, point.id)
        XCTAssertEqual(schedule.focus(at: point.startDate)?.isOngoing, false)
        XCTAssertNil(schedule.focus(at: point.startDate.addingTimeInterval(1)))
    }

    func testOvernightItemRemainsOngoingOnFollowingTravelDay() {
        let overnight = item("夜行バス", start: "2026-10-01T14:00:00Z", end: "2026-10-01T22:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [overnight]))
        let focus = schedule.focus(at: date("2026-10-01T16:00:00Z"))
        XCTAssertEqual(focus?.item.id, overnight.id)
        XCTAssertEqual(focus?.isOngoing, true)
    }

    func testOverlapsUseMostRecentlyStartedItemAndStableIdentifierTieBreak() {
        let preferred = item("後から始まる予定", start: "2026-10-01T02:00:00Z", end: "2026-10-01T04:00:00Z",
                             id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let tied = item("同時刻の予定", start: "2026-10-01T02:00:00Z", end: "2026-10-01T05:00:00Z",
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let earlier = item("先に始まる予定", start: "2026-10-01T01:00:00Z", end: "2026-10-01T06:00:00Z")
        for items in [[tied, earlier, preferred], [preferred, earlier, tied]] {
            let schedule = TripSchedule(trip: trip(items: items))
            XCTAssertEqual(schedule.focus(at: date("2026-10-01T03:00:00Z"))?.item.id, preferred.id)
            XCTAssertEqual(schedule.focus(at: date("2026-10-01T04:00:00Z"))?.item.id, tied.id)
            XCTAssertEqual(schedule.focus(at: date("2026-10-01T05:00:00Z"))?.item.id, earlier.id)
        }
    }

    func testUpcomingItemsUseChronologicalOrderAndStableIdentifierTieBreak() {
        let preferred = item("最初の予定", start: "2026-10-01T02:00:00Z",
                             id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let tied = item("同時刻の予定", start: "2026-10-01T02:00:00Z",
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let later = item("後の予定", start: "2026-10-01T03:00:00Z")
        let schedule = TripSchedule(trip: trip(items: [later, tied, preferred]))
        XCTAssertEqual(schedule.focus(at: date("2026-10-01T01:00:00Z"))?.item.id, preferred.id)
    }
}

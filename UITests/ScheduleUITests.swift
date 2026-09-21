import XCTest

final class ScheduleUITests: XCTestCase {
    private var app: XCUIApplication!
    private let sampleTitle = "京都、余白を楽しむ旅"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "--schedule-fixture",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    func testOpensTodayAndReturnsFromAnotherDay() {
        openTrip()
        capture("旅行中の案内")
        assertSelectedDay(1, date: "10月2日")
        revealAndTap(app.buttons["trip.schedule.day.0"])
        assertSelectedDay(0, date: "10月1日")
        XCTAssertEqual(app.buttons["trip.schedule.day.1"].value as? String, "未選択")

        revealAndTap(app.buttons["trip.schedule.today"])
        assertSelectedDay(1, date: "10月2日")
        reveal(app.buttons["trip.schedule.focus"])
        XCTAssertTrue(app.buttons["trip.schedule.focus"].label.contains("嵐山へ移動"))
        capture("今日のスケジュール")
    }

    func testCompletingCurrentPlanShowsNextPlanAndPersists() {
        openTrip()
        let focus = app.buttons["trip.schedule.focus"]
        reveal(focus)
        XCTAssertTrue(focus.label.contains("嵐山へ移動"))
        focus.tap()
        XCTAssertTrue(app.navigationBars["予定の詳細"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["嵐山へ移動"].waitForExistence(timeout: 5))
        let complete = app.buttons["item.complete"]
        revealAndTap(complete)
        waitForValue("完了", of: complete)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        assertFocus("竹林を歩く")
        capture("次の予定")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch()
        openTrip()
        assertSelectedDay(1, date: "10月2日")
        assertFocus("竹林を歩く")
    }

    func testNewPlansUseTodayAndThenTheSelectedDay() {
        openTrip()
        assertSelectedDay(1, date: "10月2日")
        addPlan("今日の寄り道")
        assertSelectedDay(1, date: "10月2日")
        reveal(app.staticTexts["今日の寄り道"].firstMatch)

        revealAndTap(app.buttons["trip.schedule.day.2"])
        assertSelectedDay(2, date: "10月3日")
        XCTAssertFalse(app.staticTexts["今日の寄り道"].exists)
        addPlan("帰る前にお茶")
        assertSelectedDay(2, date: "10月3日")
        reveal(app.staticTexts["帰る前にお茶"].firstMatch)
        capture("選択した日の予定を追加")

        revealAndTap(app.buttons["trip.schedule.today"])
        assertSelectedDay(1, date: "10月2日")
        XCTAssertFalse(app.staticTexts["帰る前にお茶"].exists)
        reveal(app.staticTexts["今日の寄り道"].firstMatch)
    }

    private func openTrip() {
        // The fixture clock is fixed; find the trip even after its real-world dates pass.
        let allTrips = app.segmentedControls.buttons["すべて"]
        XCTAssertTrue(allTrips.waitForExistence(timeout: 5))
        allTrips.tap()
        revealAndTap(app.staticTexts[sampleTitle].firstMatch)
        XCTAssertTrue(app.buttons["item.add"].waitForExistence(timeout: 5))
    }

    private func addPlan(_ title: String) {
        app.buttons["item.add"].tap()
        let field = app.textFields["item.title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.buttons["item.save"].waitForNonExistence(timeout: 5))
    }

    private func assertSelectedDay(_ index: Int, date: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let day = app.buttons["trip.schedule.day.\(index)"]
        reveal(day, file: file, line: line)
        waitForValue("選択中", of: day, file: file, line: line)
        let selectedDate = app.staticTexts["trip.schedule.date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(selectedDate.label.contains(date), selectedDate.label, file: file, line: line)
    }

    private func assertFocus(_ title: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let focus = app.buttons["trip.schedule.focus"]
        reveal(focus, file: file, line: line)
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", title), object: focus)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed, file: file, line: line)
    }

    private func waitForValue(_ value: String, of element: XCUIElement,
                              file: StaticString = #filePath, line: UInt = #line) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, file: file, line: line)
    }

    private func revealAndTap(_ element: XCUIElement) {
        reveal(element)
        element.tap()
    }

    private func reveal(_ element: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        for _ in 0..<5 where !element.isHittable { app.swipeDown() }
        if element.identifier.hasPrefix("trip.schedule.") {
            // Floating navigation controls can cover a schedule button that still reports hittable.
            // Use their frames: the root navigation bar also includes its bottom search field.
            for _ in 0..<4 {
                let toolbarBottom = app.navigationBars.buttons.allElementsBoundByIndex
                    .map { $0.frame.maxY }.max() ?? 0
                if element.frame.minY > toolbarBottom + 8 { break }
                app.swipeDown()
            }
            let toolbarBottom = app.navigationBars.buttons.allElementsBoundByIndex
                .map { $0.frame.maxY }.max() ?? 0
            XCTAssertGreaterThan(element.frame.minY, toolbarBottom + 8,
                                 "\(element.identifier) frame=\(element.frame), toolbarBottom=\(toolbarBottom)",
                                 file: file, line: line)
        }
        XCTAssertTrue(element.isHittable, "Could not reveal \(element.identifier), frame=\(element.frame)",
                      file: file, line: line)
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

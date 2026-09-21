import XCTest

final class BookingImportUITests: XCTestCase {
    private var app: XCUIApplication!
    private let tripTitle = "京都、余白を楽しむ旅"
    private let sourceTitle = "予約確認（テスト用）.jpg"
    private let trainID = "9C691E2A-43BD-4EA6-B503-000000000001"
    private let hotelID = "9C691E2A-43BD-4EA6-B503-000000000002"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "--booking-fixture",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    func testReviewRequiresMissingDatesAndSavesSelectedPlanWithSource() {
        openTrip()
        openReview()
        let trainTitle = app.textFields["booking.title.\(trainID)"]
        reveal(trainTitle)
        capture("画像から抽出した予定の確認")

        app.buttons["booking.save"].tap()
        let alert = app.alerts["予定を追加できませんでした"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                                            "京都のホテル", "開始日時")).firstMatch.exists)
        alert.buttons["OK"].tap()
        setSwitch(app.switches["booking.select.\(hotelID)"], enabled: false)
        replace(trainTitle, with: "朝の新幹線で京都へ")
        app.buttons["booking.save"].tap()
        XCTAssertTrue(app.buttons["booking.save"].waitForNonExistence(timeout: 5))
        goBack()

        let savedPlan = app.staticTexts["朝の新幹線で京都へ"].firstMatch
        reveal(savedPlan)
        XCTAssertFalse(app.staticTexts["京都のホテル"].exists)
        XCTAssertTrue(app.staticTexts["1 PLANS"].exists)
        capture("画像から追加した旅程")
        savedPlan.tap()
        assertSourceOpens()

        relaunch()
        openTrip()
        revealAndTap(app.staticTexts["朝の新幹線で京都へ"].firstMatch)
        XCTAssertTrue(app.staticTexts["DEMO-ONLY"].waitForExistence(timeout: 5))
        assertSourceOpens()
    }

    func testCancellingReviewKeepsTripEmptyAndPreservesSourceImage() {
        openTrip()
        let sourceIdentifier = openReview()
        replace(app.textFields["booking.title.\(trainID)"], with: "保存しない候補")
        replace(app.textFields["booking.destination"], with: "保存しない行き先")
        XCTAssertEqual(app.textFields["booking.destination"].value as? String, "保存しない行き先")
        setSwitch(app.switches["booking.destination.apply"], enabled: true)
        app.buttons["booking.cancel"].tap()
        XCTAssertTrue(app.buttons["booking.cancel"].waitForNonExistence(timeout: 5))
        goBack()
        assertEmptyTrip()

        relaunch()
        openTrip()
        assertEmptyTrip()
        revealAndTap(app.buttons["trip.tab.documents"])
        let source = app.buttons[sourceIdentifier]
        revealAndTap(source)
        assertPreview()
        capture("キャンセル後も残る元画像")
    }

    private func openTrip() {
        let allTrips = app.segmentedControls.buttons["すべて"]
        XCTAssertTrue(allTrips.waitForExistence(timeout: 5))
        allTrips.tap()
        revealAndTap(app.staticTexts[tripTitle].firstMatch)
        XCTAssertTrue(app.buttons["item.add"].waitForExistence(timeout: 5))
    }

    @discardableResult private func openReview() -> String {
        revealAndTap(app.buttons["trip.tab.documents"])
        let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch
        reveal(source)
        let identifier = source.identifier
        revealAndTap(app.buttons["booking.read.saved"])
        let option = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@",
                                                      "booking.read.", "booking.read.saved")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(app.buttons["booking.save"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["booking.title.\(trainID)"].waitForExistence(timeout: 10))
        return identifier
    }

    private func assertSourceOpens() {
        XCTAssertTrue(app.navigationBars["予定の詳細"].waitForExistence(timeout: 5))
        revealAndTap(app.buttons["item.source"])
        assertPreview()
        app.navigationBars.buttons["完了"].tap()
    }

    private func assertPreview() {
        XCTAssertTrue(app.navigationBars[sourceTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["書類を共有"].waitForExistence(timeout: 5))
    }

    private func assertEmptyTrip() {
        reveal(app.staticTexts["0 PLANS"])
        XCTAssertFalse(app.staticTexts["保存しない候補"].exists)
        XCTAssertFalse(app.staticTexts["保存しない行き先"].exists)
        XCTAssertFalse(app.staticTexts["京都行きの新幹線"].exists)
    }

    private func replace(_ field: XCUIElement, with value: String) {
        revealAndTap(field)
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + value)
    }

    private func setSwitch(_ control: XCUIElement, enabled: Bool) {
        reveal(control)
        let expected = enabled ? "1" : "0"
        if control.value as? String != expected {
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    private func revealAndTap(_ element: XCUIElement) {
        reveal(element)
        element.tap()
    }

    private func reveal(_ element: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<8 {
            if element.exists && element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        if element.identifier.hasPrefix("booking.") {
            for _ in 0..<4 {
                let toolbarBottom = app.navigationBars.buttons.allElementsBoundByIndex
                    .map { $0.frame.maxY }.max() ?? 0
                if element.frame.minY > toolbarBottom + 8 { break }
                app.swipeDown()
            }
        }
        XCTAssertTrue(element.isHittable, "Could not reveal \(element.identifier), frame=\(element.frame)",
                      file: file, line: line)
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func relaunch() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch()
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

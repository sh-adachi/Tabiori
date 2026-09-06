import XCTest

final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    func testSavedDefaultsPersistAndApplyOnlyToNewTrips() {
        createTrip("設定前の旅", expectedCurrency: "JPY")

        openSettings()
        chooseCurrency("USD")
        let checklist = app.switches["settings.checklist"]
        XCTAssertEqual(checklist.value as? String, "1")
        setChecklistEnabled(false)
        capture("設定画面")
        app.buttons["settings.save"].tap()

        relaunch()
        openSettings()
        assertCurrency("USD", identifier: "settings.currency")
        XCTAssertEqual(app.switches["settings.checklist"].value as? String, "0")
        app.buttons["settings.cancel"].tap()

        createTrip("設定後の旅", expectedCurrency: "USD")
        openTrip("設定後の旅")
        tapVisible(app.buttons["trip.tab.checklist"])
        XCTAssertTrue(app.navigationBars["旅の準備"].waitForExistence(timeout: 5))
        XCTAssertEqual(checklistItems.count, 0)
        goBack()
        goBack()

        openTrip("設定前の旅")
        app.buttons["旅行のメニュー"].tap()
        app.buttons["旅行を編集"].tap()
        assertCurrency("JPY", identifier: "trip.currency")
        app.buttons["キャンセル"].tap()
        tapVisible(app.buttons["trip.tab.checklist"])
        XCTAssertTrue(checklistItems.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(checklistItems.count, 0)
    }

    func testCancelledChangesDoNotReplaceSavedSettings() {
        openSettings()
        assertCurrency("JPY", identifier: "settings.currency")
        XCTAssertEqual(app.switches["settings.checklist"].value as? String, "1")
        chooseCurrency("USD")
        setChecklistEnabled(false)
        app.buttons["settings.cancel"].tap()

        relaunch()
        openSettings()
        assertCurrency("JPY", identifier: "settings.currency")
        XCTAssertEqual(app.switches["settings.checklist"].value as? String, "1")
        app.buttons["settings.cancel"].tap()
        createTrip("キャンセル後の旅", expectedCurrency: "JPY")
        openTrip("キャンセル後の旅")
        tapVisible(app.buttons["trip.tab.checklist"])
        XCTAssertTrue(checklistItems.firstMatch.waitForExistence(timeout: 5))
    }

    private var checklistItems: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "checklist.toggle."))
    }

    private func setChecklistEnabled(_ enabled: Bool) {
        let control = app.switches["settings.checklist"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if control.isHittable { break }
            app.swipeUp()
        }
        let expected = enabled ? "1" : "0"
        if control.value as? String != expected {
            // The native form exposes the whole row as the switch's frame.
            // Target its trailing control instead of the label at row center.
            control.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    private func openSettings() {
        let button = app.buttons["settings.open"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["settings.save"].waitForExistence(timeout: 5))
    }

    private func chooseCurrency(_ code: String) {
        tapVisible(app.buttons["settings.currency"])
        let option = app.buttons[code].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        assertCurrency(code, identifier: "settings.currency")
    }

    private func assertCurrency(_ code: String, identifier: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.buttons[identifier]
        for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.waitForExistence(timeout: 5), file: file, line: line)
        let showsCode = (picker.value as? String)?.contains(code) == true
            || picker.label.contains(code) || picker.staticTexts[code].exists
        XCTAssertTrue(showsCode, "Expected \(identifier) to show \(code); label=\(picker.label), value=\(String(describing: picker.value))", file: file, line: line)
    }

    private func createTrip(_ title: String, expectedCurrency: String) {
        app.buttons["trip.add"].tap()
        let titleField = app.textFields["trip.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        assertCurrency(expectedCurrency, identifier: "trip.currency")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
    }

    private func openTrip(_ title: String) {
        tapVisible(app.staticTexts[title].firstMatch)
        XCTAssertTrue(app.buttons["item.add"].waitForExistence(timeout: 5))
    }

    private func tapVisible(_ element: XCUIElement) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        for _ in 0..<5 where !element.isHittable { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
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

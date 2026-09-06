import XCTest

final class TabioriUITests: XCTestCase {
    private var app: XCUIApplication!
    private let sampleTitle = "京都、余白を楽しむ旅"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
    }

    func testSampleTripOpensItineraryDocumentsAndMap() {
        openSample()
        XCTAssertTrue(app.buttons["item.add"].waitForExistence(timeout: 5))
        capture("旅程")

        revealAndTap(app.buttons["trip.tab.documents"])
        XCTAssertTrue(app.staticTexts["書類"].firstMatch.waitForExistence(timeout: 5)
                      || app.staticTexts["写真・PDF"].firstMatch.exists)
        capture("写真とPDF")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        revealAndTap(app.buttons["trip.tab.map"])
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
        app.buttons["map.stops"].tap()
        let stop = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "map.stop.")).firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(app.buttons["Apple マップで経路を調べる"].waitForExistence(timeout: 5))
        capture("旅のマップ")
    }

    func testTripAndItineraryPersistAfterRelaunch() {
        createTrip(title: "金沢の週末", destination: "金沢")
        openTrip("金沢の週末")
        revealAndTap(app.buttons["item.add"])
        let itemTitle = app.textFields["item.title"]
        XCTAssertTrue(itemTitle.waitForExistence(timeout: 5))
        itemTitle.tap()
        itemTitle.typeText("近江町市場でランチ")
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts["近江町市場でランチ"].firstMatch.waitForExistence(timeout: 5))

        relaunchPreservingData()
        let savedTrip = app.staticTexts["金沢の週末"].firstMatch
        XCTAssertTrue(savedTrip.waitForExistence(timeout: 5))
        savedTrip.tap()
        XCTAssertTrue(app.staticTexts["近江町市場でランチ"].firstMatch.waitForExistence(timeout: 5))
        capture("保存した旅程")
    }

    func testCancelledEditsStayUnchangedAndDeletedTripDoesNotReturn() {
        app.buttons["trip.add"].tap()
        fill(app.textFields["trip.title"], with: "保存しない旅")
        app.buttons["キャンセル"].tap()
        XCTAssertFalse(app.staticTexts["保存しない旅"].exists)

        createTrip(title: "金沢の週末", destination: "金沢")
        openTrip("金沢の週末")
        app.buttons["旅行のメニュー"].tap()
        app.buttons["旅行を編集"].tap()
        replace(app.textFields["trip.title"], with: "取り消す変更")
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["金沢の週末"].exists)

        app.buttons["旅行のメニュー"].tap()
        app.buttons["旅行を編集"].tap()
        replace(app.textFields["trip.title"], with: "大阪への旅")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.navigationBars["大阪への旅"].waitForExistence(timeout: 5))
        relaunchPreservingData()
        openTrip("大阪への旅")
        app.buttons["旅行のメニュー"].tap()
        app.buttons["旅行を削除"].tap()
        app.buttons["旅行と添付ファイルを削除"].tap()
        XCTAssertTrue(app.buttons["sample.add"].waitForExistence(timeout: 5))
        relaunchPreservingData()
        XCTAssertFalse(app.staticTexts["大阪への旅"].exists)
        XCTAssertTrue(app.buttons["sample.add"].exists)
    }

    func testManualLocationAppearsOnMapAfterRelaunch() {
        createTrip(title: "金沢の週末", destination: "金沢")
        openTrip("金沢の週末")
        revealAndTap(app.buttons["item.add"])
        fill(app.textFields["item.title"], with: "市場でランチ")
        revealAndTap(app.buttons["item.place"])
        revealAndTap(app.buttons["place.manual"])
        fill(app.textFields["place.name"], with: "近江町市場")
        fill(app.textFields["place.latitude"], with: "36.5715")
        fill(app.textFields["place.longitude"], with: "136.6565")
        revealAndTap(app.buttons["place.save"])
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts["市場でランチ"].firstMatch.waitForExistence(timeout: 5))

        relaunchPreservingData()
        openTrip("金沢の週末")
        revealAndTap(app.buttons["trip.tab.map"])
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
        let pin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "map.pin.")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, "市場でランチ、近江町市場")
        pin.tap()
        XCTAssertTrue(app.staticTexts["近江町市場"].firstMatch.waitForExistence(timeout: 5))
        capture("手動で登録した場所")
    }

    func testChecklistStatePersistsAfterRelaunch() {
        openSample()
        revealAndTap(app.buttons["trip.tab.checklist"])
        let toggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "checklist.toggle.")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let identifier = toggle.identifier
        let wasChecked = (toggle.value as? String) == "完了"
        toggle.tap()
        let expected = wasChecked ? "未完了" : "完了"
        XCTAssertEqual(toggle.value as? String, expected)

        relaunchPreservingData()
        let trip = app.staticTexts[sampleTitle].firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 5))
        trip.tap()
        revealAndTap(app.buttons["trip.tab.checklist"])
        let savedToggle = app.buttons[identifier]
        XCTAssertTrue(savedToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(savedToggle.value as? String, expected)
        capture("持ち物チェック")
    }

    func testPhotoImportPreviewPersistsAndDeletion() {
        openSample()
        revealAndTap(app.buttons["trip.tab.documents"])
        app.buttons["documents.photo"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@", "Photo,", "写真、", "写真,", "写真，")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20), "Prepare simulator fixtures first.\n\(app.debugDescription)")
        // iOS 26's remote Photos picker reports visible thumbnails as non-hittable.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let document = firstDocument
        XCTAssertTrue(document.waitForExistence(timeout: 20), app.debugDescription)
        let id = document.identifier
        document.tap()
        XCTAssertTrue(app.buttons["書類を共有"].waitForExistence(timeout: 10))
        capture("写真プレビュー")
        app.navigationBars.buttons["完了"].tap()
        relaunchPreservingData()
        openTrip(sampleTitle)
        revealAndTap(app.buttons["trip.tab.documents"])
        let saved = app.buttons[id]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(app.buttons["書類を共有"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["完了"].tap()
        saved.swipeLeft()
        app.buttons["削除"].tap()
        app.buttons["書類を削除"].tap()
        XCTAssertTrue(saved.waitForNonExistence(timeout: 5))
        relaunchPreservingData()
        openTrip(sampleTitle)
        revealAndTap(app.buttons["trip.tab.documents"])
        XCTAssertFalse(app.buttons[id].exists)
    }

    func testPDFImportsThroughFilesAndPersists() {
        openSample()
        revealAndTap(app.buttons["trip.tab.documents"])
        app.buttons["documents.add"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), app.debugDescription)
        search.tap()
        search.typeText("Tabiori-Test-Ticket")
        let ticket = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Tabiori-Test-Ticket")).matching(NSPredicate(format: "elementType != %d", XCUIElement.ElementType.searchField.rawValue)).firstMatch
        XCTAssertTrue(ticket.waitForExistence(timeout: 15), app.debugDescription)
        ticket.tap()
        let open = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "開く", "Open")).firstMatch
        if open.waitForExistence(timeout: 3) { open.tap() }
        XCTAssertTrue(firstDocument.waitForExistence(timeout: 15), app.debugDescription)
        let id = firstDocument.identifier
        firstDocument.tap()
        XCTAssertTrue(app.buttons["書類を共有"].waitForExistence(timeout: 10))
        capture("PDFプレビュー")
        app.navigationBars.buttons["完了"].tap()
        relaunchPreservingData()
        openTrip(sampleTitle)
        revealAndTap(app.buttons["trip.tab.documents"])
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5))
        capture("予約書類")
    }

    private var firstDocument: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "document.")).firstMatch
    }

    func testLivePlaceSearchAndSave() {
        createTrip(title: "京都への旅行", destination: "京都")
        openTrip("京都への旅行")
        app.buttons["item.add"].tap()
        fill(app.textFields["item.title"], with: "京都駅に集合")
        revealAndTap(app.buttons["item.place"])
        fill(app.textFields["place.query"], with: "京都駅 京都 日本")
        app.buttons["place.search"].tap()
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "place.result.")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Apple Maps search needs an internet connection.\n\(app.debugDescription)")
        XCTAssertTrue(result.label.contains("京都"))
        capture("場所検索")
        result.tap()
        app.buttons["item.save"].tap()
        relaunchPreservingData()
        openTrip("京都への旅行")
        revealAndTap(app.buttons["trip.tab.map"])
        let pin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "map.pin.")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertTrue(pin.label.contains("京都駅に集合"))
    }

    private func openSample() {
        let button = app.buttons["sample.add"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        revealAndTap(button)
        let title = app.staticTexts[sampleTitle].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        capture("旅行一覧")
        title.tap()
    }

    private func createTrip(title: String, destination: String) {
        app.buttons["trip.add"].firstMatch.tap()
        fill(app.textFields["trip.title"], with: title)
        fill(app.textFields["trip.destination"], with: destination)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 5))
    }

    private func openTrip(_ title: String) {
        revealAndTap(app.staticTexts[title].firstMatch)
        XCTAssertTrue(app.buttons["item.add"].waitForExistence(timeout: 5))
    }

    private func fill(_ field: XCUIElement, with text: String) {
        revealAndTap(field)
        field.typeText(text)
    }

    private func replace(_ field: XCUIElement, with text: String) {
        revealAndTap(field)
        let oldValue = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + text)
    }

    private func revealAndTap(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.isHittable { break }
            app.swipeUp()
        }
        for _ in 0..<5 {
            if element.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
    }

    private func relaunchPreservingData() {
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-data" }
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

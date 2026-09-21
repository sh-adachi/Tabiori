import XCTest

/// Explicit device-only check: generated sample image -> real Vision -> real Apple Intelligence.
final class LiveBookingAITests: XCTestCase {
    func testOnDeviceAIReadsSampleTicket() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("端末内AIの推論確認はApple Intelligenceを有効にした実機で実行します。")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data", "--booking-live-fixture",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let trip = app.staticTexts["京都、余白を楽しむ旅"].firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 10))
        trip.tap()
        let documents = app.buttons["trip.tab.documents"]
        XCTAssertTrue(documents.waitForExistence(timeout: 5))
        documents.tap()
        let read = app.buttons["booking.read.saved"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        if !read.isHittable { app.swipeUp() }
        read.tap()
        let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@",
                                                      "booking.read.", "booking.read.saved")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        let title = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "booking.title.")).firstMatch
        let found = title.waitForExistence(timeout: 120)
        let result = XCTAttachment(screenshot: app.screenshot())
        result.name = "実機Apple Intelligenceの読み取り結果"
        result.lifetime = .keepAlways
        add(result)
        XCTAssertTrue(found, "端末内AIの結果がありません。\n\(app.debugDescription)")
        XCTAssertFalse((title.value as? String ?? "").isEmpty)
        let reservation = app.textFields.matching(NSPredicate(format: "value == %@", "DEMO-ONLY")).firstMatch
        for _ in 0..<5 where !reservation.exists { app.swipeUp() }
        XCTAssertTrue(reservation.exists, "画像に明記した予約番号を抽出できませんでした。\n\(app.debugDescription)")
        let details = XCTAttachment(screenshot: app.screenshot())
        details.name = "実機で抽出した予約番号"
        details.lifetime = .keepAlways
        add(details)
        app.buttons["booking.cancel"].tap()
        #endif
    }
}

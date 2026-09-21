import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import AttachmentSupport

final class BookingOCRTests: XCTestCase {
    private func image(lines: [String]) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1600, height: 800,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 800))
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 52, nil)
        for (index, text) in lines.enumerated() {
            let string = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ])
            context.textPosition = CGPoint(x: 70, y: 690 - index * 95)
            CTLineDraw(CTLineCreateWithAttributedString(string), context)
        }
        let data = NSMutableData()
        let output = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(output, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(output))
        return data as Data
    }

    func testJapaneseBookingImageUsesRealOCR() throws {
        let data = try image(lines: ["予約確認", "東京から京都", "2026年10月15日 09:30", "のぞみ123号"])
        let text = try BookingExtractionService.recognizeText(in: data)
        XCTAssertTrue(text.contains("予約"), text)
        XCTAssertTrue(text.contains("京都"), text)
        XCTAssertTrue(text.contains("2026"), text)
        XCTAssertTrue(text.contains("09:30"), text)
    }

    func testEnglishFlightImageUsesRealOCR() throws {
        let data = try image(lines: ["FLIGHT CONFIRMATION", "Tokyo to London", "2026-10-15 13:45", "Flight AB123"])
        let text = try BookingExtractionService.recognizeText(in: data)
        XCTAssertTrue(text.uppercased().contains("FLIGHT"), text)
        XCTAssertTrue(text.contains("London"), text)
        XCTAssertTrue(text.contains("13:45"), text)
        XCTAssertTrue(text.contains("AB123"), text)
    }

    func testBlankImageReturnsNoTextError() throws {
        XCTAssertThrowsError(try BookingExtractionService.recognizeText(in: image(lines: []))) { error in
            guard case BookingExtractionError.noText = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testEmptyAndMalformedImageAreRejectedBeforeOCR() {
        XCTAssertThrowsError(try BookingExtractionService.recognizeText(in: Data())) { error in
            guard case AttachmentImportError.empty = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertThrowsError(try BookingExtractionService.recognizeText(in: Data("invalid image".utf8))) { error in
            guard case AttachmentImportError.invalidPhoto = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    func testLongOCRIsRejectedInsteadOfSilentlyTruncated() throws {
        try BookingExtractionService.validateTextLength(String(repeating: "旅", count: 1_200))
        XCTAssertThrowsError(try BookingExtractionService.validateTextLength(String(repeating: "旅", count: 1_201))) { error in
            guard case BookingExtractionError.tooMuchText = error else { return XCTFail("Unexpected error: \(error)") }
        }
    }

    private func parse(_ date: String, zone: String = "Asia/Tokyo") -> BookingExtractionService.ParsedMoment {
        BookingExtractionService.parseMoment(date, timeZoneIdentifier: zone,
            fallbackTimeZone: TimeZone(identifier: "Asia/Tokyo")!, label: "開始")
    }

    func testUnknownAndPartialDatesRemainNil() {
        for value in ["", "2026-10-15", "10-15 09:30", "2026-10-15 09", "2026-10-15T09:30:00", "2026-10-15 09:30 extra"] {
            let result = parse(value)
            XCTAssertNil(result.date, value)
            XCTAssertFalse(result.warnings.isEmpty, value)
        }
    }

    func testInvalidCalendarComponentsAreNotNormalized() {
        for value in ["2026-02-29 09:30", "2026-04-31 09:30", "2026-13-01 09:30", "2026-10-15 24:00", "2026-10-15 09:60"] {
            XCTAssertNil(parse(value).date, value)
        }
        XCTAssertNotNil(parse("2028-02-29 09:30").date)
    }

    func testExplicitZonesPreserveDifferentLocalFlightTimes() throws {
        let tokyo = try XCTUnwrap(parse("2026-10-15 09:30").date)
        let london = try XCTUnwrap(parse("2026-10-15 09:30", zone: "Europe/London").date)
        XCTAssertEqual(london.timeIntervalSince(tokyo), 8 * 3600)
        XCTAssertEqual(parse("2026-10-15 09:30", zone: "+09:00").date, tokyo)
        XCTAssertTrue(parse("2026-10-15 09:30", zone: "Asia/Tokyo").warnings.isEmpty)
    }

    func testMissingZoneWarnsAndUnknownZoneDoesNotFallBack() {
        let assumed = parse("2026-10-15 09:30", zone: "")
        XCTAssertEqual(assumed.date, parse("2026-10-15 09:30").date)
        XCTAssertTrue(assumed.warnings.contains { $0.contains("Asia/Tokyo") })
        for zone in ["CST", "Mars/City", "+14:30", "+25:00"] {
            XCTAssertNil(parse("2026-10-15 09:30", zone: zone).date, zone)
        }
    }

    func testDaylightSavingGapAndOverlapRemainUnresolved() {
        XCTAssertNil(parse("2026-03-08 02:30", zone: "America/New_York").date)
        XCTAssertNil(parse("2026-11-01 01:30", zone: "America/New_York").date)
        XCTAssertNotNil(parse("2026-11-01 01:30", zone: "-04:00").date)
        XCTAssertNotNil(parse("2026-11-01 03:30", zone: "America/New_York").date)
    }
}

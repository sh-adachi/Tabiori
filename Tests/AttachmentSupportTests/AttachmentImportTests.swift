import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import TravelCore
import UniformTypeIdentifiers
import XCTest
@testable import AttachmentSupport

final class AttachmentImportTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TabioriImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func makeImage(width: Int, height: Int, type: UTType = .jpeg,
                           transparent: Bool = false, properties: [CFString: Any] = [:]) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        if !transparent {
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func imageSource(_ data: Data) throws -> CGImageSource {
        try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    }

    private func makePDF() throws -> Data {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        var bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 10, y: 10, width: 180, height: 80))
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    func testLargePhotoIsNormalizedToBoundedJPEG() throws {
        let input = try makeImage(width: 4000, height: 2000)
        let prepared = try AttachmentImport.preparePhoto(input, displayName: "旅の写真.jpg")
        let output = try imageSource(prepared.data)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(output, 0, nil))
        XCTAssertEqual(prepared.kind, .photo)
        XCTAssertEqual(prepared.displayName, "旅の写真.jpg")
        XCTAssertEqual(CGImageSourceGetType(output) as String?, UTType.jpeg.identifier)
        XCTAssertEqual(image.width, 2560)
        XCTAssertEqual(image.height, 1280)
    }

    func testExifOrientationIsAppliedAndPrivateMetadataRemoved() throws {
        let input = try makeImage(width: 80, height: 40, properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 35.0,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 135.0,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private reservation metadata"]
        ])
        let inputProperties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(try imageSource(input), 0, nil) as? [CFString: Any])
        XCTAssertEqual(inputProperties[kCGImagePropertyOrientation] as? Int, 6)
        XCTAssertNotNil(inputProperties[kCGImagePropertyGPSDictionary])
        let inputExif = inputProperties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNotNil(inputExif?[kCGImagePropertyExifUserComment])

        let prepared = try AttachmentImport.preparePhoto(input, displayName: "回転写真.jpg")
        let output = try imageSource(prepared.data)
        let outputImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(output, 0, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        XCTAssertEqual(outputImage.width, 40)
        XCTAssertEqual(outputImage.height, 80)
        XCTAssertEqual((properties[kCGImagePropertyOrientation] as? Int) ?? 1, 1)
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifUserComment])
    }

    func testTransparentPNGUsesWhiteJPEGBackground() throws {
        let input = try makeImage(width: 16, height: 16, type: .png, transparent: true)
        let inputURL = directory.appendingPathComponent("透明.png")
        try input.write(to: inputURL)
        let prepared = try AttachmentImport.prepareFile(inputURL)
        XCTAssertEqual(prepared.displayName, "透明.jpg")
        let output = try imageSource(prepared.data)
        XCTAssertEqual(CGImageSourceGetType(output) as String?, UTType.jpeg.identifier)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(output, 0, nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let channels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        XCTAssertGreaterThan(channels[0], 245)
        XCTAssertGreaterThan(channels[1], 245)
        XCTAssertGreaterThan(channels[2], 245)
    }

    func testMalformedPhotoIsRejected() throws {
        XCTAssertThrowsError(try AttachmentImport.preparePhoto(Data("not an image".utf8), displayName: "image.jpg")) { error in
            guard case AttachmentImportError.invalidPhoto = error else {
                return XCTFail("Expected invalidPhoto, received \(error)")
            }
        }
    }

    func testRealPDFDetectedByHeaderAndPreserved() throws {
        let data = try makePDF()
        let url = directory.appendingPathComponent("予約.bin")
        try data.write(to: url)
        let prepared = try AttachmentImport.prepareFile(url)
        XCTAssertEqual(prepared.kind, .pdf)
        XCTAssertEqual(prepared.displayName, "予約.bin")
        XCTAssertEqual(prepared.data, data)
        XCTAssertEqual(PDFDocument(data: prepared.data)?.pageCount, 1)
    }

    func testMalformedPDFIsRejected() throws {
        let url = directory.appendingPathComponent("壊れた予約.pdf")
        try Data("%PDF-1.7\nThis file has no PDF structure.".utf8).write(to: url)
        XCTAssertThrowsError(try AttachmentImport.prepareFile(url)) { error in
            guard case AttachmentImportError.invalidPDF = error else {
                return XCTFail("Expected invalidPDF, received \(error)")
            }
        }
    }

    func testPasswordProtectedPDFIsRejected() throws {
        let document = try XCTUnwrap(PDFDocument(data: makePDF()))
        let url = directory.appendingPathComponent("保護された予約.pdf")
        XCTAssertTrue(document.write(to: url, withOptions: [
            .ownerPasswordOption: "test-owner-password", .userPasswordOption: "test-user-password"
        ]))
        XCTAssertEqual(PDFDocument(url: url)?.isLocked, true)
        XCTAssertThrowsError(try AttachmentImport.prepareFile(url)) { error in
            guard case AttachmentImportError.lockedPDF = error else {
                return XCTFail("Expected lockedPDF, received \(error)")
            }
        }
    }

    func testLimitedReaderReadsMultipleChunksAndEnforcesFileLimit() throws {
        let url = directory.appendingPathComponent("import.bin")
        let data = Data((0..<(64 * 1024 + 17)).map { UInt8($0 % 251) })
        try data.write(to: url)
        XCTAssertEqual(try AttachmentImport.readLimited(url), data)

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(AttachmentRepository.maximumFileSize))
        XCTAssertEqual(try AttachmentImport.readLimited(url).count, AttachmentRepository.maximumFileSize)
        try handle.truncate(atOffset: UInt64(AttachmentRepository.maximumFileSize + 1))
        XCTAssertThrowsError(try AttachmentImport.readLimited(url)) { error in
            guard case AttachmentImportError.tooLarge = error else {
                return XCTFail("Expected tooLarge, received \(error)")
            }
        }
        try handle.truncate(atOffset: 0)
        XCTAssertThrowsError(try AttachmentImport.readLimited(url)) { error in
            guard case AttachmentImportError.empty = error else {
                return XCTFail("Expected empty, received \(error)")
            }
        }
    }
}

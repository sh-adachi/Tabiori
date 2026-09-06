import CoreTransferable
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import TravelCore
#endif

struct PreparedAttachment: Sendable {
    let data: Data
    let displayName: String
    let kind: AttachmentKind
}

struct ImportedPhoto: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            ImportedPhoto(data: try AttachmentImport.readLimited(received.file))
        }
    }
}

enum AttachmentImport {
    /// Reads at most the allowed size plus one byte, even if the file grows while reading.
    static func readLimited(_ url: URL) throws -> Data {
        let limit = AttachmentRepository.maximumFileSize
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > limit {
            throw AttachmentImportError.tooLarge
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= limit {
            let chunk = try handle.read(upToCount: min(64 * 1024, limit + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= limit else { throw AttachmentImportError.tooLarge }
        guard !data.isEmpty else { throw AttachmentImportError.empty }
        return data
    }

    static func prepareFile(_ url: URL) throws -> PreparedAttachment {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try readLimited(url)
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        if url.pathExtension.lowercased() == "pdf" || type?.conforms(to: .pdf) == true || data.starts(with: Data("%PDF-".utf8)) {
            guard let document = PDFDocument(data: data) else { throw AttachmentImportError.invalidPDF }
            guard !document.isLocked else { throw AttachmentImportError.lockedPDF }
            guard document.pageCount > 0 else { throw AttachmentImportError.invalidPDF }
            return PreparedAttachment(data: data, displayName: url.lastPathComponent, kind: .pdf)
        }
        return try preparePhoto(data, displayName: url.deletingPathExtension().lastPathComponent + ".jpg")
    }

    /// ImageIO downsamples before decoding and applies EXIF orientation. Re-encoding
    /// gives every photo a consistent JPEG payload and removes source metadata.
    static func preparePhoto(_ data: Data, displayName: String) throws -> PreparedAttachment {
        guard data.count <= AttachmentRepository.maximumFileSize else { throw AttachmentImportError.tooLarge }
        guard !data.isEmpty else { throw AttachmentImportError.empty }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else { throw AttachmentImportError.invalidPhoto }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard let width = properties?[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties?[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 120_000_000 else {
            throw AttachmentImportError.imageDimensions
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_560,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AttachmentImportError.invalidPhoto
        }
        // Composite transparent images onto white before JPEG encoding.
        guard let context = CGContext(data: nil, width: thumbnail.width, height: thumbnail.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw AttachmentImportError.invalidPhoto
        }
        let bounds = CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(thumbnail, in: bounds)
        guard let opaqueImage = context.makeImage() else { throw AttachmentImportError.invalidPhoto }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw AttachmentImportError.invalidPhoto
        }
        CGImageDestinationAddImage(destination, opaqueImage, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw AttachmentImportError.invalidPhoto }
        let normalized = output as Data
        guard normalized.count <= AttachmentRepository.maximumFileSize else { throw AttachmentImportError.tooLarge }
        return PreparedAttachment(data: normalized, displayName: displayName, kind: .photo)
    }
}

enum AttachmentImportError: LocalizedError {
    case tooLarge, empty, invalidPhoto, imageDimensions, invalidPDF, lockedPDF, message(String)

    var errorDescription: String? {
        switch self {
        case .tooLarge: "ファイルは 1 件につき 25 MB 以下にしてください。"
        case .empty: "ファイルが空のため読み込めませんでした。"
        case .invalidPhoto: "この画像を読み込めませんでした。JPEG・PNG・HEIC などの画像を選んでください。"
        case .imageDimensions: "画像の解像度が大きすぎるか、不正です。1 億 2,000 万画素以下の画像を選んでください。"
        case .invalidPDF: "この PDF を読み込めませんでした。ファイルを確認してください。"
        case .lockedPDF: "パスワードで保護された PDF は、保護を解除したコピーを選んでください。"
        case .message(let message): message
        }
    }
}

import Foundation

/// Persists all trips as a single, atomically replaced JSON document.
public struct TravelRepository: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("trips.json", isDirectory: false) }

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    public func load() throws -> [Trip] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let trips = try decoder.decode([Trip].self, from: data)
        try TripValidator.validateAll(trips)
        return trips
    }

    public func save(_ trips: [Trip]) throws {
        try TripValidator.validateAll(trips)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(trips)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

public struct AttachmentRepository: Sendable {
    public static let maximumFileSize = 25 * 1024 * 1024
    public let directory: URL

    public init(directory: URL) { self.directory = directory.standardizedFileURL }

    public func store(data: Data, displayName: String, kind: AttachmentKind,
                      itemID: UUID? = nil) throws -> TravelAttachment {
        guard !data.isEmpty else { throw TravelDataError.emptyAttachment }
        guard data.count <= Self.maximumFileSize else { throw TravelDataError.attachmentTooLarge }
        let id = UUID()
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = TravelAttachment(id: id,
            displayName: cleanName.isEmpty ? (kind == .photo ? "写真.jpg" : "書類.pdf") : cleanName,
            fileName: "\(id.uuidString).\(kind.fileExtension)", kind: kind, itemID: itemID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(attachment.fileName, isDirectory: false)
        try data.write(to: destination, options: .atomic)
        return attachment
    }

    public func url(for attachment: TravelAttachment) throws -> URL {
        try AttachmentFileName.validate(attachment)
        let url = directory.appendingPathComponent(attachment.fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TravelDataError.attachmentMissing
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw TravelDataError.unsafeFileName
        }
        return url
    }

    public func remove(_ attachment: TravelAttachment) throws {
        try AttachmentFileName.validate(attachment)
        let candidate = directory.appendingPathComponent(attachment.fileName, isDirectory: false)
        // Deleting an already removed file is safe and makes rollback retryable.
        guard FileManager.default.fileExists(atPath: candidate.path) else { return }
        let safeURL = try url(for: attachment)
        try FileManager.default.removeItem(at: safeURL)
    }
}

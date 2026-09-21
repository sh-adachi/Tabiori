import Foundation

public enum ItemKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case train, flight, bus, restaurant, hotel, activity, other

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .train: return "電車"
        case .flight: return "飛行機"
        case .bus: return "バス"
        case .restaurant: return "飲食店"
        case .hotel: return "宿泊"
        case .activity: return "観光・体験"
        case .other: return "その他"
        }
    }
    public var symbol: String {
        switch self {
        case .train: return "tram.fill"
        case .flight: return "airplane"
        case .bus: return "bus.fill"
        case .restaurant: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .activity: return "camera.fill"
        case .other: return "mappin.and.ellipse"
        }
    }
    public var isTransport: Bool { self == .train || self == .flight || self == .bus }
}

public struct Place: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double

    public init(name: String = "", address: String = "", latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ItineraryItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: ItemKind
    public var startDate: Date
    public var endDate: Date?
    public var departure: String
    public var arrival: String
    public var serviceNumber: String
    public var reservationCode: String
    public var notes: String
    public var cost: Double
    public var location: Place?
    public var isCompleted: Bool
    public var sourceAttachmentID: UUID?

    public init(id: UUID = UUID(), title: String, kind: ItemKind = .activity, startDate: Date,
                endDate: Date? = nil, departure: String = "", arrival: String = "",
                serviceNumber: String = "", reservationCode: String = "", notes: String = "",
                cost: Double = 0, location: Place? = nil, isCompleted: Bool = false,
                sourceAttachmentID: UUID? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.departure = departure
        self.arrival = arrival
        self.serviceNumber = serviceNumber
        self.reservationCode = reservationCode
        self.notes = notes
        self.cost = cost
        self.location = location
        self.isCompleted = isCompleted
        self.sourceAttachmentID = sourceAttachmentID
    }
}

public enum AttachmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo, pdf
    public var id: String { rawValue }
    public var title: String { self == .photo ? "写真" : "PDF" }
    public var symbol: String { self == .photo ? "photo" : "doc.richtext" }
    public var fileExtension: String { self == .photo ? "jpg" : "pdf" }
}

public struct TravelAttachment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var fileName: String
    public var kind: AttachmentKind
    public var createdAt: Date
    public var itemID: UUID?

    public init(id: UUID = UUID(), displayName: String, fileName: String,
                kind: AttachmentKind, createdAt: Date = Date(), itemID: UUID? = nil) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.kind = kind
        self.createdAt = createdAt
        self.itemID = itemID
    }
}

public struct ChecklistItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var isChecked: Bool

    public init(id: UUID = UUID(), title: String, isChecked: Bool = false) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
    }
}

public struct Trip: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var destination: String
    public var startDate: Date
    public var endDate: Date
    public var timeZoneIdentifier: String
    public var currencyCode: String
    public var budget: Double
    public var notes: String
    public var items: [ItineraryItem]
    public var attachments: [TravelAttachment]
    public var checklist: [ChecklistItem]
    public var createdAt: Date

    public init(id: UUID = UUID(), title: String = "", destination: String = "",
                startDate: Date = Date(), endDate: Date = Date(),
                timeZoneIdentifier: String = "Asia/Tokyo", currencyCode: String = "JPY",
                budget: Double = 0, notes: String = "", items: [ItineraryItem] = [],
                attachments: [TravelAttachment] = [], checklist: [ChecklistItem] = [],
                createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.currencyCode = currencyCode
        self.budget = budget
        self.notes = notes
        self.items = items
        self.attachments = attachments
        self.checklist = checklist
        self.createdAt = createdAt
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)! }
    public var sortedItems: [ItineraryItem] {
        items.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    public var totalCost: Double { items.reduce(0) { $0 + $1.cost } }
}

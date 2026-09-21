import Foundation

/// Provider-independent output. Candidates stay separate from saved plans until reviewed.
public struct BookingExtraction: Sendable {
    public var destination: String
    public var candidates: [BookingCandidate]
    public var warnings: [String]

    public init(destination: String = "", candidates: [BookingCandidate] = [], warnings: [String] = []) {
        self.destination = destination
        self.candidates = candidates
        self.warnings = warnings
    }
}

public struct BookingCandidate: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: ItemKind
    public var startDate: Date?
    public var endDate: Date?
    public var departure: String
    public var arrival: String
    public var serviceNumber: String
    public var reservationCode: String
    public var notes: String
    public var placeName: String
    public var placeAddress: String
    public var warnings: [String]
    public var isSelected: Bool

    public init(id: UUID = UUID(), title: String = "", kind: ItemKind = .other,
                startDate: Date? = nil, endDate: Date? = nil,
                departure: String = "", arrival: String = "", serviceNumber: String = "",
                reservationCode: String = "", notes: String = "", placeName: String = "",
                placeAddress: String = "", warnings: [String] = [], isSelected: Bool = true) {
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
        self.placeName = placeName
        self.placeAddress = placeAddress
        self.warnings = warnings
        self.isSelected = isSelected
    }
}

public enum BookingImport {
    /// A reservation code alone does not identify a plan: return journeys often share it.
    public static func duplicate(of candidate: BookingCandidate, in trip: Trip) -> ItineraryItem? {
        guard let start = candidate.startDate else { return nil }
        let title = normalized(candidate.title)
        let service = normalized(candidate.serviceNumber)
        let reservation = normalized(candidate.reservationCode)
        let departure = normalized(candidate.departure)
        let arrival = normalized(candidate.arrival)

        return trip.items.first { item in
            guard item.kind == candidate.kind, item.startDate == start else { return false }
            if !title.isEmpty, normalized(item.title) == title { return true }
            guard normalized(item.departure) == departure, normalized(item.arrival) == arrival else { return false }
            return (!service.isEmpty && normalized(item.serviceNumber) == service)
                || (!reservation.isEmpty && normalized(item.reservationCode) == reservation)
        }
    }

    /// Returns a fully validated copy; callers persist it once after the review is confirmed.
    /// Passing a nonempty destination is an explicit request to change the trip destination.
    public static func applying(_ candidates: [BookingCandidate], sourceAttachmentID: UUID,
                                destination: String?, expandTripDates: Bool, to trip: Trip) throws -> Trip {
        try TripValidator.validate(trip)
        guard trip.attachments.contains(where: { $0.id == sourceAttachmentID }) else {
            throw TravelDataError.attachmentMissing
        }
        let selected = candidates.filter(\.isSelected)
        guard !selected.isEmpty else {
            throw TravelDataError.invalid("追加する予定を1件以上選んでください。")
        }

        var updated = trip
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone

        for candidate in selected {
            guard !updated.items.contains(where: { $0.id == candidate.id }) else {
                throw TravelDataError.duplicateID
            }
            let title = trimmed(candidate.title)
            guard !title.isEmpty else {
                throw TravelDataError.invalid("追加する予定の名前を入力してください。")
            }
            guard let start = candidate.startDate, start.timeIntervalSince1970.isFinite else {
                throw TravelDataError.invalid("「\(title)」の開始日時を確認してください。")
            }
            if let end = candidate.endDate {
                guard end.timeIntervalSince1970.isFinite, end >= start else {
                    throw TravelDataError.invalid("「\(title)」の終了日時を開始日時以降にしてください。")
                }
            }
            if let existing = duplicate(of: candidate, in: updated) {
                throw TravelDataError.invalid("「\(title)」は「\(existing.title)」と同じ予定の可能性があります。追加する予定を見直してください。")
            }

            var notes = [trimmed(candidate.notes)]
            let placeName = trimmed(candidate.placeName)
            let placeAddress = trimmed(candidate.placeAddress)
            if !placeName.isEmpty { notes.append("場所：\(placeName)") }
            if !placeAddress.isEmpty { notes.append("住所：\(placeAddress)") }
            updated.items.append(ItineraryItem(
                id: candidate.id, title: title, kind: candidate.kind, startDate: start,
                endDate: candidate.endDate, departure: trimmed(candidate.departure),
                arrival: trimmed(candidate.arrival), serviceNumber: trimmed(candidate.serviceNumber),
                reservationCode: trimmed(candidate.reservationCode),
                notes: notes.filter { !$0.isEmpty }.joined(separator: "\n"),
                sourceAttachmentID: sourceAttachmentID
            ))

            if expandTripDates {
                let startDay = calendar.startOfDay(for: start)
                let endDay = calendar.startOfDay(for: candidate.endDate ?? start)
                if startDay < calendar.startOfDay(for: updated.startDate) { updated.startDate = startDay }
                if endDay > calendar.startOfDay(for: updated.endDate) { updated.endDate = endDay }
            }
        }

        if let destination, !trimmed(destination).isEmpty { updated.destination = trimmed(destination) }
        try TripValidator.validate(updated)
        return updated
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                      locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

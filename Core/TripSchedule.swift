import Foundation

public struct TripSchedule {
    public let trip: Trip

    public init(trip: Trip) {
        self.trip = trip
    }

    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone
        return calendar
    }

    public var days: [Date] {
        let calendar = calendar
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        var days = [Date]()
        var date = start
        // Validation caps trip length; also bound enumeration for malformed drafts.
        while date <= end && days.count < 367 {
            days.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }

    public func today(at now: Date) -> Date? {
        let day = calendar.startOfDay(for: now)
        return days.contains(day) ? day : nil
    }

    public func selectedDay(_ selection: Date?, at now: Date) -> Date {
        let days = days
        if let selection, days.contains(selection) { return selection }
        return today(at: now) ?? days.first ?? trip.startDate
    }

    public struct Focus {
        public let item: ItineraryItem
        public let isOngoing: Bool
    }

    public func focus(at now: Date) -> Focus? {
        guard today(at: now) != nil else { return nil }
        let incompleteItems = trip.sortedItems.filter { !$0.isCompleted }
        let ongoing = incompleteItems.filter { item in
            guard let end = item.endDate else { return false }
            return item.startDate <= now && now < end
        }.sorted {
            if $0.startDate != $1.startDate { return $0.startDate > $1.startDate }
            return $0.id.uuidString < $1.id.uuidString
        }.first
        if let ongoing { return Focus(item: ongoing, isOngoing: true) }
        guard let upcoming = incompleteItems.first(where: { $0.startDate >= now }) else { return nil }
        return Focus(item: upcoming, isOngoing: false)
    }
}

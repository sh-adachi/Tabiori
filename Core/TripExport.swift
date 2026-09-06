import Foundation

public enum TripExport {
    public static func text(for trip: Trip) -> String {
        let date = DateFormatter()
        date.locale = Locale(identifier: "ja_JP")
        date.timeZone = trip.timeZone
        date.dateFormat = "yyyy年M月d日(E)"
        let time = DateFormatter()
        time.locale = date.locale
        time.timeZone = trip.timeZone
        time.dateFormat = "HH:mm"
        let money = NumberFormatter()
        money.locale = Locale(identifier: "ja_JP")
        money.numberStyle = .currency
        money.currencyCode = trip.currencyCode
        func amount(_ value: Double) -> String {
            money.string(from: NSNumber(value: value)) ?? "\(value) \(trip.currencyCode)"
        }

        var lines = [trip.title]
        if !trip.destination.isEmpty { lines.append("行き先: \(trip.destination)") }
        lines.append("\(date.string(from: trip.startDate)) 〜 \(date.string(from: trip.endDate))")
        lines.append("時刻: \(trip.timeZoneIdentifier)")
        lines.append("費用合計: \(amount(trip.totalCost))")
        if trip.budget > 0 { lines.append("予算: \(amount(trip.budget))") }
        if !trip.notes.isEmpty { lines += ["", "旅のメモ", trip.notes] }

        var previousDay = ""
        for item in trip.sortedItems {
            let day = date.string(from: item.startDate)
            if day != previousDay {
                lines += ["", day]
                previousDay = day
            }
            var hours = time.string(from: item.startDate)
            if let end = item.endDate {
                let endDay = date.string(from: end)
                hours += endDay == day ? "–\(time.string(from: end))" : "–\(endDay) \(time.string(from: end))"
            }
            lines.append("\(item.isCompleted ? "✓" : "・") \(hours) [\(item.kind.title)] \(item.title)")
            if !item.departure.isEmpty || !item.arrival.isEmpty {
                lines.append("  \(item.departure) → \(item.arrival)")
            }
            if !item.serviceNumber.isEmpty { lines.append("  便・列車番号: \(item.serviceNumber)") }
            if !item.reservationCode.isEmpty { lines.append("  予約番号: \(item.reservationCode)") }
            if let place = item.location {
                if !place.name.isEmpty { lines.append("  場所: \(place.name)") }
                if !place.address.isEmpty { lines.append("  住所: \(place.address)") }
                lines.append("  地図: https://maps.apple.com/?ll=\(place.latitude),\(place.longitude)")
            }
            if item.cost > 0 { lines.append("  費用: \(amount(item.cost))") }
            if !item.notes.isEmpty { lines.append("  メモ: \(item.notes)") }
        }
        if !trip.checklist.isEmpty {
            lines += ["", "持ち物・準備"]
            lines += trip.checklist.map { "\($0.isChecked ? "☑" : "☐") \($0.title)" }
        }
        if !trip.attachments.isEmpty {
            lines += ["", "添付ファイル（ファイル本体は別途共有してください）"]
            lines += trip.attachments.map { "・\($0.displayName)" }
        }
        return lines.joined(separator: "\n")
    }
}

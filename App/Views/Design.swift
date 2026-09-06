import SwiftUI

enum AppTheme {
    static let ink = Color.primary
    static let teal = Color(red: 0.08, green: 0.43, blue: 0.40)
    static let coral = Color(red: 0.84, green: 0.35, blue: 0.23)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

extension ItemKind {
    var tint: Color {
        switch self {
        case .train, .bus: return AppTheme.teal
        case .flight: return .blue
        case .restaurant: return AppTheme.coral
        case .hotel: return .indigo
        case .activity: return Color(red: 0.57, green: 0.39, blue: 0.10)
        case .other: return .secondary
        }
    }
}

enum TripDate {
    static func format(_ date: Date, pattern: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
    static func day(_ date: Date, timeZone: TimeZone) -> String { format(date, pattern: "M月d日（E）", timeZone: timeZone) }
    static func time(_ date: Date, timeZone: TimeZone) -> String { format(date, pattern: "HH:mm", timeZone: timeZone) }
    static func range(_ trip: Trip) -> String {
        format(trip.startDate, pattern: "yyyy.M.d", timeZone: trip.timeZone) + " — " + format(trip.endDate, pattern: "M.d", timeZone: trip.timeZone)
    }
    static func money(_ value: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(currency)"
    }
    static func calendar(for trip: Trip) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = trip.timeZone
        return calendar
    }
    static func days(_ trip: Trip) -> [Date] {
        let calendar = calendar(for: trip)
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        var days = [Date]()
        var date = start
        // Core validation caps trip length; this guard also protects a malformed draft.
        while date <= end && days.count < 367 {
            days.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return days
    }
}

struct SymbolBadge: View {
    let symbol: String
    var color: Color = AppTheme.teal
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct SmallLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct TravelArtwork: View {
    var compact = false
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(colors: [Color(red: 0.07, green: 0.29, blue: 0.28), AppTheme.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.045)).frame(width: size.width * 0.9).offset(x: size.width * 0.3, y: -size.height * 0.3)
                ForEach(0..<5) { index in
                    Path { path in
                        let offset = CGFloat(index) * 20
                        path.move(to: CGPoint(x: -30, y: size.height + offset - 55))
                        path.addCurve(to: CGPoint(x: size.width + 30, y: offset + 30), control1: CGPoint(x: size.width * 0.4, y: -offset), control2: CGPoint(x: size.width * 0.6, y: size.height + offset))
                    }.stroke(.white.opacity(0.09), lineWidth: 1)
                }
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.57, y: size.height * 0.76))
                    path.addQuadCurve(to: CGPoint(x: size.width * 0.85, y: size.height * 0.25), control: CGPoint(x: size.width * 0.48, y: size.height * 0.14))
                }.stroke(Color(red: 0.92, green: 0.78, blue: 0.49).opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
                Image(systemName: "paperplane.fill").font(.system(size: compact ? 27 : 44, weight: .light))
                    .rotationEffect(.degrees(-12)).foregroundStyle(Color(red: 0.94, green: 0.85, blue: 0.64))
                    .position(x: size.width * 0.84, y: size.height * 0.24)
                Circle().fill(Color(red: 0.94, green: 0.85, blue: 0.64)).frame(width: 7, height: 7)
                    .position(x: size.width * 0.57, y: size.height * 0.76)
            }
        }.accessibilityHidden(true)
    }
}

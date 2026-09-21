import Foundation

/// Day and streak figures are always computed, never stored.
enum Stats {

    static func todayTotal(_ sessions: [Session], now: Date = .now) -> TimeInterval {
        let cal = Calendar.current
        return sessions
            .filter { $0.counts && cal.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.elapsed }
    }

    /// Consecutive days, ending today or yesterday, with at least one kept block.
    static func streak(_ sessions: [Session], now: Date = .now) -> Int {
        let cal = Calendar.current
        let days = Set(sessions.filter(\.counts).map { cal.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }

        var cursor = cal.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(total)s"
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

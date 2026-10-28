import Foundation

/// Day and streak figures are always computed, never stored.
enum Stats {

    static func todayTotal(_ sessions: [Session], now: Date = .now) -> TimeInterval {
        let cal = Calendar.current
        return sessions
            .filter { $0.counts && cal.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.elapsed }
    }

    /// How many missed days a streak can absorb without resetting.
    enum Forgiveness {
        /// Every miss resets the streak.
        case none
        /// Free: the first missed day in the user's history is forgiven, once
        /// and never again. Computed from the history rather than stored, so it
        /// is the same answer every time it's asked.
        case firstMiss
        /// Pro: one missed day in any seven is forgiven, for good.
        case weekly
    }

    /// Consecutive days with at least one kept block, ending today or
    /// yesterday. Today never counts against it — it isn't over. Forgiven days
    /// keep the streak alive but don't add to it.
    static func streak(
        _ sessions: [Session],
        now: Date = .now,
        forgiveness: Forgiveness = .none
    ) -> Int {
        let cal = Calendar.current
        let days = Set(sessions.filter(\.counts).map { cal.startOfDay(for: $0.startedAt) })
        guard let first = days.min() else { return 0 }
        let today = cal.startOfDay(for: now)

        let firstMiss: Date? = {
            guard forgiveness == .firstMiss else { return nil }
            var d = first
            while d < today {
                if !days.contains(d) { return d }
                guard let next = cal.date(byAdding: .day, value: 1, to: d) else { return nil }
                d = next
            }
            return nil
        }()

        var cursor = today
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        var lastForgiven: Date?
        while cursor >= first {
            if days.contains(cursor) {
                count += 1
            } else {
                let forgiven: Bool = switch forgiveness {
                case .none:
                    false
                case .firstMiss:
                    cursor == firstMiss
                case .weekly:
                    lastForgiven.map {
                        (cal.dateComponents([.day], from: cursor, to: $0).day ?? 0) >= 7
                    } ?? true
                }
                guard forgiven else { break }
                lastForgiven = cursor
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Total kept time in the calendar unit containing `now` — the week or the
    /// month. Pro shows these; the free tier only ever sees today.
    static func total(
        _ sessions: [Session],
        in unit: Calendar.Component,
        now: Date = .now
    ) -> TimeInterval {
        let cal = Calendar.current
        return sessions
            .filter { $0.counts && cal.isDate($0.startedAt, equalTo: now, toGranularity: unit) }
            .reduce(0) { $0 + $1.elapsed }
    }

    struct DayTotal: Identifiable {
        let day: Date
        let total: TimeInterval
        var id: Date { day }
    }

    /// Kept time per day for the last `days` days, oldest first. Days with
    /// nothing in them are present and zero — a gap is part of the shape.
    static func daily(_ sessions: [Session], days: Int, now: Date = .now) -> [DayTotal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let total = sessions
                .filter { $0.counts && cal.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.elapsed }
            return DayTotal(day: day, total: total)
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(total)s"
    }

    /// Spelled out for VoiceOver. `format` produces "18m", which a screen
    /// reader pronounces "eighteen em".
    static func spoken(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

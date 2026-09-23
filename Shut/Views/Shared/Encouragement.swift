import Foundation

/// Optional short notes, shown only when the user turns them on in Settings.
///
/// Off by default: the app's own voice is plain and dry, and this is the one
/// place the user can ask it to be warmer. Even then it never uses emoji, never
/// exaggerates, and never scolds — a broken block gets a clean slate, not a
/// lecture.
///
/// Each line is picked from the block's start time, so it stays put for the
/// whole block (and for each progress stage) instead of changing on every tick.
enum Encouragement {
    enum Moment: Equatable {
        case running(progress: Double, openEnded: Bool)
        case grace(HingeMonitor.Trigger)
        case kept
        case broken
    }

    static func line(for moment: Moment, seed: Date?) -> String {
        let pool = pool(for: moment)
        let n = Int((seed?.timeIntervalSince1970 ?? 0).rounded(.down))
        return pool[((n % pool.count) + pool.count) % pool.count]
    }

    static func pool(for moment: Moment) -> [String] {
        switch moment {
        case .running(_, true):
            ["Still shut. Still going.", "Every minute here counts.", "Good focus."]
        case .running(let progress, false) where progress >= 0.85:
            ["Nearly there.", "Last stretch.", "Almost yours."]
        case .running(let progress, false) where progress >= 0.5:
            ["Past halfway.", "More behind you than ahead.", "Holding steady."]
        case .running:
            ["Good start. Keep it shut.", "Nothing else needs you right now.", "Settle in."]
        case .grace(.fold):
            ["Fold it back. You were doing well.", "No harm yet. Close it and carry on."]
        case .grace(.lock):
            ["Lock it again. You were doing well.", "No harm yet. Lock it and carry on."]
        case .kept:
            ["Well kept.", "That time was yours.", "Good work. That one counts."]
        case .broken:
            ["It happens. The next one starts clean.", "Pick a length and go again."]
        }
    }
}

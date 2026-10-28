import Foundation
import SwiftData

enum SessionOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case broken
    case abandoned

    var display: String {
        switch self {
        case .completed: "Kept"
        case .broken:    "Broken"
        case .abandoned: "Stopped"
        }
    }
}

@Model
final class Session {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    /// Target length in seconds. Zero means open-ended.
    var targetSeconds: Int = 0
    var outcomeRaw: String = SessionOutcome.abandoned.rawValue
    var interruptions: Int = 0
    /// Pro only.
    var label: String?

    init(startedAt: Date = .now, targetSeconds: Int) {
        self.id = UUID()
        self.startedAt = startedAt
        self.targetSeconds = targetSeconds
    }

    var outcome: SessionOutcome {
        get { SessionOutcome(rawValue: outcomeRaw) ?? .abandoned }
        set { outcomeRaw = newValue.rawValue }
    }

    var isOpenEnded: Bool { targetSeconds == 0 }

    var elapsed: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    /// Counts toward daily totals and streaks.
    var counts: Bool { outcome == .completed }
}

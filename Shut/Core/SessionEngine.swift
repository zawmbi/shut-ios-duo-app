import Foundation
import Observation
import SwiftData
import UserNotifications

/// The state machine. Owns every transition; views only read it and call the
/// three intent methods (`arm`, `disarm`, `breakNow`).
///
/// ```
/// idle ──arm──▶ armed ──committed──▶ running
/// running ──released──▶ grace ──recommitted──▶ running
///                        └──expired──▶ broken
/// running ──target reached──▶ complete
/// ```
@MainActor
@Observable
final class SessionEngine {

    enum Phase: Equatable {
        case idle
        case armed
        case running
        case grace
        case complete
        case broken
    }

    private(set) var phase: Phase = .idle
    private(set) var startedAt: Date?
    private(set) var graceEndsAt: Date?
    private(set) var interruptions: Int = 0
    private(set) var lastFinished: Session?

    var targetSeconds: Int = 25 * 60

    /// Read from preferences each time a block is released, so a change in
    /// Settings applies to the next interruption rather than the next launch.
    var graceSeconds: Int { Prefs.graceSeconds }

    private var context: ModelContext?
    private var lastPosture: HingeMonitor.Posture = .open
    /// When the user released mid-block. A broken or abandoned block ended
    /// here, not when the grace period ran out afterwards.
    private var releasedAt: Date?

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: - Derived

    var isActive: Bool { phase == .running || phase == .grace }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, Date.now.timeIntervalSince(startedAt))
    }

    var remaining: TimeInterval? {
        guard targetSeconds > 0, startedAt != nil else { return nil }
        return max(0, Double(targetSeconds) - elapsed)
    }

    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(1, elapsed / Double(targetSeconds))
    }

    var graceRemaining: TimeInterval {
        guard let graceEndsAt else { return 0 }
        return max(0, graceEndsAt.timeIntervalSince(.now))
    }

    // MARK: - Intents

    func arm(target: Int) {
        targetSeconds = target
        startedAt = nil
        graceEndsAt = nil
        releasedAt = nil
        interruptions = 0
        lastFinished = nil
        phase = .armed
    }

    func disarm() {
        cancelNotification()
        phase = .idle
        startedAt = nil
        graceEndsAt = nil
        releasedAt = nil
    }

    /// The user chose to end the block early, from the interrupt screen.
    func breakNow() {
        guard isActive else { return }
        finish(as: .abandoned)
    }

    func acknowledge() {
        phase = .idle
        startedAt = nil
        graceEndsAt = nil
        releasedAt = nil
        lastFinished = nil
    }

    // MARK: - Inputs

    /// Single entry point for hardware state. Idempotent: repeated identical
    /// postures are ignored, so a chatty sensor can't inflate the interruption
    /// count.
    func handle(posture: HingeMonitor.Posture) {
        defer { lastPosture = posture }
        guard posture != lastPosture else { return }

        // Settle a block that already reached its target before reading the new
        // posture. No tick ran while the phone was shut — the process was
        // suspended — so without this, opening the phone on a block that
        // finished an hour ago reads as an interruption and breaks it.
        tick()

        switch (phase, posture.isCommitted) {
        case (.armed, true):
            start()
        case (.running, false):
            interruptions += 1
            releasedAt = .now
            graceEndsAt = .now.addingTimeInterval(Double(graceSeconds))
            phase = .grace
        case (.grace, true):
            graceEndsAt = nil
            releasedAt = nil
            phase = .running
        default:
            break
        }
    }

    /// Called on every clock tick. Pure function of stored dates — safe to miss.
    func tick() {
        switch phase {
        case .running:
            if targetSeconds > 0, elapsed >= Double(targetSeconds) {
                finish(as: .completed)
            }
        case .grace:
            if graceRemaining <= 0 {
                finish(as: .broken)
            }
        default:
            break
        }
    }

    // MARK: - Transitions

    private func start() {
        startedAt = .now
        phase = .running
        scheduleNotification()
    }

    private func finish(as outcome: SessionOutcome) {
        cancelNotification()
        guard let startedAt else {
            phase = .idle
            return
        }

        let session = Session(startedAt: startedAt, targetSeconds: targetSeconds)
        // A completed block ends at its target, not at the moment the user
        // happened to open the phone afterwards; a broken one ends when they
        // opened it, not when the grace period ran out.
        let endedAt: Date = switch outcome {
        case .completed where targetSeconds > 0:
            startedAt.addingTimeInterval(Double(targetSeconds))
        case .completed:
            Date.now
        case .broken, .abandoned:
            releasedAt ?? Date.now
        }
        session.endedAt = endedAt
        session.outcome = outcome
        session.interruptions = interruptions

        context?.insert(session)
        try? context?.save()

        lastFinished = session
        phase = outcome == .completed ? .complete : .broken
        self.startedAt = nil
        graceEndsAt = nil
        releasedAt = nil
    }

    // MARK: - Notifications

    private static let notificationID = "shut.block.finished"

    private func scheduleNotification() {
        guard targetSeconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Done."
        content.body = "\(targetSeconds / 60) minutes. You can open it."
        content.sound = Prefs.soundOnFinish ? .default : nil
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(targetSeconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}

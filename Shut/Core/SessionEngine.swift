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
///
/// An open-ended block has no target, so opening the phone is how it ends: its
/// release finishes it as kept, at the moment of release, rather than broken.
///
/// A block in flight is mirrored to defaults on every transition, so a process
/// the system killed while the phone was locked — or that the user force-quit —
/// comes back where it was and settles from its stored dates.
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

    /// The clock, as a seam. Production reads the wall clock; tests substitute a
    /// fake so the engine can be driven across hours without waiting for them.
    /// Every date the engine stores or compares comes through here — if a new
    /// `Date.now` appears anywhere below, that is a bug, not a shortcut.
    @ObservationIgnored
    var now: @MainActor () -> Date = { .now }

    /// Read from preferences each time a block is released, so a change in
    /// Settings applies to the next interruption rather than the next launch.
    var graceSeconds: Int { Prefs.graceSeconds }

    /// Where the in-flight block is mirrored. A seam for the same reason as
    /// `now`: tests use a throwaway suite.
    @ObservationIgnored
    var store: UserDefaults = .standard

    private var context: ModelContext?
    private var lastPosture: HingeMonitor.Posture = .open
    /// When the user released mid-block. A broken or abandoned block ended
    /// here, not when the grace period ran out afterwards.
    private var releasedAt: Date?

    func configure(context: ModelContext) {
        self.context = context
        restore()
    }

    // MARK: - Derived

    var isActive: Bool { phase == .running || phase == .grace }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return max(0, now().timeIntervalSince(startedAt))
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
        return max(0, graceEndsAt.timeIntervalSince(now()))
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
        persist()
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
        persist()
    }

    // MARK: - Inputs

    /// Single entry point for hardware state. Idempotent: repeated identical
    /// postures are ignored, so a chatty sensor can't inflate the interruption
    /// count.
    ///
    /// `date` is when the change actually happened. It is earlier than now when
    /// `HingeMonitor` only worked out after the fact that the user left the app
    /// or locked the screen.
    func handle(posture: HingeMonitor.Posture, at date: Date? = nil) {
        defer { lastPosture = posture }
        guard posture != lastPosture else { return }

        let at = min(date ?? now(), now())

        // Settle a block that already reached its target before reading the new
        // posture — as of when the posture changed, not as of now. No tick ran
        // while the phone was shut, so without this, opening the phone on a
        // block that finished an hour ago reads as an interruption and breaks
        // it; and a user who left the app a minute before the end, and came back
        // a minute after it, would be credited with a block they didn't keep.
        tick(asOf: at)

        switch (phase, posture.isCommitted) {
        case (.armed, true):
            start(at: at)
        case (.running, false):
            interruptions += 1
            releasedAt = at
            graceEndsAt = at.addingTimeInterval(Double(graceSeconds))
            phase = .grace
            cancelNotification()
            persist()
            // A release dated in the past may already be out of grace.
            tick()
        case (.grace, true):
            graceEndsAt = nil
            releasedAt = nil
            phase = .running
            scheduleNotification()
            persist()
        default:
            break
        }
    }

    /// Called on every clock tick. Pure function of stored dates — safe to miss.
    func tick() { tick(asOf: now()) }

    private func tick(asOf date: Date) {
        switch phase {
        case .running:
            if targetSeconds > 0, let startedAt,
               date.timeIntervalSince(startedAt) >= Double(targetSeconds) {
                finish(as: .completed)
            }
        case .grace:
            if let graceEndsAt, graceEndsAt <= date {
                finish(as: .broken)
            }
        default:
            break
        }
    }

    // MARK: - Transitions

    private func start(at date: Date) {
        startedAt = date
        phase = .running
        scheduleNotification()
        persist()
    }

    private func finish(as requested: SessionOutcome) {
        // An open-ended block has nothing to fall short of: however it ends,
        // the time before the release was kept.
        let outcome: SessionOutcome = targetSeconds == 0 ? .completed : requested

        // A completed block leaves its notification alone — it is due now, or
        // already delivered, and it carries the end-of-block sound.
        if outcome != .completed { cancelNotification() }
        defer { persist() }
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
        case .completed, .broken, .abandoned:
            releasedAt ?? now()
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

    /// Scheduled for whatever is left, each time the block enters `.running`,
    /// and cancelled each time it leaves. The wording only says the time is up,
    /// never that the block was kept: if the process dies, this still fires,
    /// and it must not claim something nobody checked.
    private func scheduleNotification() {
        guard let remaining, remaining > 0 else { return }
        let minutes = targetSeconds / 60
        let content = UNMutableNotificationContent()
        content.title = "Time's up."
        content.body = "\(minutes) minute\(minutes == 1 ? "" : "s"). You can open it."
        content.sound = Prefs.soundOnFinish ? UNNotificationSound.default : nil
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: remaining,
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

    // MARK: - Surviving the process

    private struct InFlight: Codable {
        var running: Bool
        var startedAt: Date
        var targetSeconds: Int
        var interruptions: Int
        var releasedAt: Date?
        var graceEndsAt: Date?
    }

    private func persist() {
        guard isActive, let startedAt else {
            store.removeObject(forKey: PrefKey.inFlight)
            return
        }
        let snapshot = InFlight(
            running: phase == .running,
            startedAt: startedAt,
            targetSeconds: targetSeconds,
            interruptions: interruptions,
            releasedAt: releasedAt,
            graceEndsAt: graceEndsAt
        )
        store.set(try? JSONEncoder().encode(snapshot), forKey: PrefKey.inFlight)
    }

    /// Picks up a block the previous process left in flight, then settles it
    /// from its stored dates. A running block stays running — the posture that
    /// arrives next decides what happens to it, exactly as if the process had
    /// only been suspended.
    func restore() {
        guard let data = store.data(forKey: PrefKey.inFlight),
              let snapshot = try? JSONDecoder().decode(InFlight.self, from: data) else { return }
        startedAt = snapshot.startedAt
        targetSeconds = snapshot.targetSeconds
        interruptions = snapshot.interruptions
        releasedAt = snapshot.releasedAt
        graceEndsAt = snapshot.graceEndsAt
        phase = snapshot.running ? .running : .grace
        lastPosture = snapshot.running ? .closed : .open
        tick()
    }
}

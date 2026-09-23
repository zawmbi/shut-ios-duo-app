import Foundation
import SwiftUI
import Testing

@testable import Shut

/// The state machine, on a fake clock.
///
/// Ported from `Tools/logic-check/engine_check.py`, case for case. The Python
/// harness proved the algorithm; this proves the Swift, which is the only thing
/// that ships.
///
/// Serialized because `SessionEngine.graceSeconds` reads `UserDefaults` through
/// `Prefs`, and `Prefs` is process-wide. Parallel cases would fight over it.
@MainActor
@Suite(.serialized)
struct SessionEngineTests {

    // MARK: - Harness

    /// Drives an engine the way the device does: nothing ticks while the phone
    /// is shut, because the process is suspended.
    @MainActor
    final class Harness {
        let engine = SessionEngine()
        private let clock: Clock

        @MainActor
        final class Clock {
            /// An arbitrary fixed instant. Every assertion is relative, so the
            /// value only has to be stable, not meaningful.
            var t = Date(timeIntervalSinceReferenceDate: 800_000_000)
        }

        /// Where the engine mirrors its in-flight block. A fresh suite per
        /// harness, so no case can see another's block.
        let store: UserDefaults

        init(grace: Int = Prefs.defaultGraceSeconds, pro: Bool = true) {
            UserDefaults.standard.set(grace, forKey: PrefKey.graceSeconds)
            UserDefaults.standard.set(pro, forKey: PrefKey.proCached)
            let clock = Clock()
            self.clock = clock
            engine.now = { clock.t }
            let suite = "shut.tests.\(UUID().uuidString)"
            store = UserDefaults(suiteName: suite)!
            store.removePersistentDomain(forName: suite)
            engine.store = store
        }

        deinit {
            UserDefaults.standard.removeObject(forKey: PrefKey.graceSeconds)
            UserDefaults.standard.removeObject(forKey: PrefKey.proCached)
        }

        /// The current instant on the fake clock, for dating a posture change.
        func at(_ t: TimeInterval) -> Date {
            Date(timeIntervalSinceReferenceDate: 800_000_000 + t)
        }

        func handle(_ posture: HingeMonitor.Posture, at t: TimeInterval) {
            engine.handle(posture: posture, at: at(t))
        }

        /// A second engine on the same clock and store — the process the system
        /// launches after killing this one.
        func relaunch() -> SessionEngine {
            let next = SessionEngine()
            next.now = engine.now
            next.store = store
            next.restore()
            return next
        }

        /// Seconds since the harness started, as the engine sees them.
        private var elapsedFromOrigin: TimeInterval {
            clock.t.timeIntervalSinceReferenceDate - 800_000_000
        }

        /// Time passes with the app awake: tick four times a second, the way
        /// `SessionClock` drives it.
        func awake(until t: TimeInterval) {
            while elapsedFromOrigin < t {
                clock.t = clock.t.addingTimeInterval(
                    min(0.25, t - elapsedFromOrigin)
                )
                engine.tick()
            }
        }

        /// Time passes with the phone shut: no ticks at all.
        func shut(until t: TimeInterval) {
            clock.t = Date(timeIntervalSinceReferenceDate: 800_000_000 + t)
        }

        func arm(_ target: Int) { engine.arm(target: target) }
        func handle(_ posture: HingeMonitor.Posture) { engine.handle(posture: posture) }

        var phase: SessionEngine.Phase { engine.phase }
        var interruptions: Int { engine.interruptions }
        var finished: Session? { engine.lastFinished }
        var outcome: SessionOutcome? { engine.lastFinished?.outcome }
        /// The length the finished block was credited with.
        var credited: TimeInterval? { engine.lastFinished?.elapsed }
    }

    // MARK: - BUILD.md's end-of-day-1 test

    @Test("A one-minute block, folded the whole way through, is Kept for 1m")
    func minuteBlockFoldedThrough() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 61)
        h.handle(.open)

        #expect(h.phase == .complete)
        #expect(h.outcome == .completed)
        #expect(h.credited == 60)
        #expect(Stats.format(h.credited ?? 0) == "1m")
    }

    @Test("Opened early, grace runs out: Broken")
    func openedEarlyGraceExpires() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 21)

        #expect(h.phase == .broken)
        #expect(h.outcome == .broken)
    }

    @Test("A broken block ended when they opened it, not when grace ran out")
    func brokenBlockEndsAtRelease() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 21)

        #expect(h.credited == 10)
    }

    // MARK: - The bug the engine fix was for

    @Test("A block that finished hours ago reads as Kept, not Broken, when opened")
    func finishedLongAgoThenOpened() {
        let h = Harness()
        h.arm(25 * 60)
        h.handle(.closed)
        h.shut(until: 3 * 3600)
        h.handle(.open)

        #expect(h.phase == .complete)
        #expect(h.outcome == .completed)
    }

    @Test("... credited its target, not the three hours it sat shut")
    func finishedLongAgoCreditsTarget() {
        let h = Harness()
        h.arm(25 * 60)
        h.handle(.closed)
        h.shut(until: 3 * 3600)
        h.handle(.open)

        // Spelled as a TimeInterval: the expectation macro resolves a bare
        // `25 * 60` as Int and then compares it against a Double, which fails
        // on two values that are equal.
        #expect(h.credited == TimeInterval(25 * 60))
    }

    @Test("... and opening it afterwards is not an interruption")
    func finishedLongAgoIsNotAnInterruption() {
        let h = Harness()
        h.arm(25 * 60)
        h.handle(.closed)
        h.shut(until: 3 * 3600)
        h.handle(.open)

        #expect(h.finished?.interruptions == 0)
    }

    @Test("Opened at the exact target second: Kept")
    func openedExactlyOnTarget() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 60)
        h.handle(.open)

        #expect(h.outcome == .completed)
    }

    @Test("Opened half a second early: Broken")
    func openedHalfASecondEarly() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 59.5)
        h.handle(.open)
        h.awake(until: 70)

        #expect(h.outcome == .broken)
    }

    // MARK: - Grace

    @Test("Refolding inside the grace window keeps the block")
    func refoldInsideGrace() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 15)
        h.handle(.closed)
        h.shut(until: 61)
        h.handle(.open)

        #expect(h.outcome == .completed)
    }

    @Test("... and records exactly one interruption")
    func refoldRecordsOneInterruption() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 15)
        h.handle(.closed)
        h.shut(until: 61)
        h.handle(.open)

        #expect(h.finished?.interruptions == 1)
    }

    @Test("... and still credits the full target")
    func refoldCreditsFullTarget() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 15)
        h.handle(.closed)
        h.shut(until: 61)
        h.handle(.open)

        #expect(h.credited == 60)
    }

    @Test("Pro's 30-second grace is still running at 25 seconds")
    func longGraceStillRunning() {
        let h = Harness(grace: 30)
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 35)

        #expect(h.phase == .grace)
    }

    @Test("Pro's 30-second grace expires at 31 seconds")
    func longGraceExpires() {
        let h = Harness(grace: 30)
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 41)

        #expect(h.phase == .broken)
    }

    @Test("Break it is Stopped, not Broken")
    func breakNowIsAbandoned() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.engine.breakNow()

        #expect(h.outcome == .abandoned)
    }

    // MARK: - Open-ended blocks

    @Test("An open-ended block never self-completes; opening it ends it Kept")
    func openEndedKeptOnOpen() {
        let h = Harness()
        h.arm(0)
        h.handle(.closed)
        h.shut(until: 1800)
        h.handle(.open)
        h.awake(until: 1811)

        #expect(h.outcome == .completed)
    }

    @Test("... and so does ending it from the grace screen")
    func openEndedEndItIsKept() {
        let h = Harness()
        h.arm(0)
        h.handle(.closed)
        h.shut(until: 600)
        h.handle(.open)
        h.engine.breakNow()

        #expect(h.outcome == .completed)
        #expect(h.credited == 600)
    }

    @Test("... and is credited the time it was actually shut")
    func openEndedCreditsTimeShut() {
        let h = Harness()
        h.arm(0)
        h.handle(.closed)
        h.shut(until: 1800)
        h.handle(.open)
        h.awake(until: 1811)

        #expect(h.credited == 1800)
    }

    // MARK: - Sensor noise

    @Test("Repeated identical postures record one interruption, not five")
    func chattySensor() {
        let h = Harness()
        h.arm(60)
        for _ in 0..<5 { h.handle(.closed) }
        h.shut(until: 10)
        for _ in 0..<5 { h.handle(.open) }

        #expect(h.interruptions == 1)
    }

    @Test("Partially open releases the block")
    func partialReleases() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.partial)

        #expect(h.phase == .grace)
    }

    @Test("... and folding back resumes it")
    func refoldFromPartialResumes() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.partial)
        h.handle(.closed)

        #expect(h.phase == .running)
    }

    // MARK: - Leaving the app, dated after the fact

    @Test("Left at 24m of 25, back at 30m: Broken at 24m, not Kept")
    func leftBeforeTargetReturnedAfter() {
        let h = Harness()
        h.arm(25 * 60)
        h.handle(.closed)
        h.shut(until: 30 * 60)
        h.handle(.open, at: 24 * 60)

        #expect(h.outcome == .broken)
        #expect(h.credited == 1440)
    }

    @Test("Left at 30m of 25: the block was already Kept")
    func leftAfterTarget() {
        let h = Harness()
        h.arm(25 * 60)
        h.handle(.closed)
        h.shut(until: 31 * 60)
        h.handle(.open, at: 30 * 60)

        #expect(h.outcome == .completed)
        #expect(h.credited == 1500)
    }

    @Test("A release discovered 5s late still leaves 5s of grace")
    func lateReleaseKeepsRemainingGrace() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 25)
        h.handle(.open, at: 20)

        #expect(h.phase == .grace)
        #expect(h.engine.graceRemaining == 5)
    }

    @Test("A lock discovered late starts the block when the lock happened")
    func lateLockStartsBackdated() {
        let h = Harness()
        h.arm(60)
        h.shut(until: 15)
        h.handle(.closed, at: 3)

        #expect(h.engine.startedAt == h.at(3))
    }

    // MARK: - Surviving the process

    @Test("Killed while locked, relaunched after the target: Kept")
    func relaunchAfterTargetIsKept() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 90)
        let next = h.relaunch()

        #expect(next.lastFinished?.outcome == .completed)
    }

    @Test("Killed while locked, relaunched before the target: still running")
    func relaunchBeforeTargetResumes() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 30)
        let next = h.relaunch()

        #expect(next.phase == .running)
        #expect(next.startedAt == h.at(0))
    }

    @Test("Force-quit after leaving: relaunch settles it Broken at the release")
    func relaunchAfterLeavingIsBroken() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 20)
        h.handle(.open)
        h.shut(until: 50)
        let next = h.relaunch()

        #expect(next.lastFinished?.outcome == .broken)
        #expect(next.lastFinished?.elapsed == 20)
    }

    @Test("A finished block leaves nothing to restore")
    func nothingInFlightAfterFinish() {
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 61)
        h.handle(.open)

        #expect(h.relaunch().phase == .idle)
    }

    // MARK: - Pro gates survive a refund

    @Test("A refunded user's stored 30s grace falls back to 10s")
    func refundedGraceFallsBack() {
        let h = Harness(grace: 30, pro: false)
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 10)
        h.handle(.open)
        h.awake(until: 21)

        #expect(h.phase == .broken)
    }

    // MARK: - The lock path: scene phase

    /// A monitor on a throwaway defaults suite, optionally already knowing the
    /// device has a passcode.
    private func monitor(passcode: Bool) -> HingeMonitor {
        let suite = "shut.tests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        store.removePersistentDomain(forName: suite)
        store.set(passcode, forKey: PrefKey.passcodeSeen)
        return HingeMonitor(store: store)
    }

    @Test("Locking the screen commits the block")
    func lockCommits() {
        let m = monitor(passcode: true)
        m.ingestScenePhase(.background)
        m.deviceLocked()
        #expect(m.posture == .closed)
    }

    @Test("The first lock ever seen commits too, and teaches it there's a passcode")
    func firstLockLatchesPasscode() {
        let m = monitor(passcode: false)
        m.ingestScenePhase(.background)
        m.deviceLocked()
        #expect(m.posture == .closed)
        #expect(m.hasPasscode)
    }

    @Test("With a passcode, going home without locking is a release")
    func leavingIsARelease() {
        let m = monitor(passcode: true)
        m.ingestScenePhase(.background)
        m.lockWindowElapsed()
        #expect(m.posture == .open)
    }

    @Test("... dated when the user left, not when the wait ran out")
    func leavingIsDatedAtDeparture() {
        let m = monitor(passcode: true)
        var t = Date(timeIntervalSinceReferenceDate: 0)
        m.now = { t }
        var got: Date?
        m.onPosture = { _, date in got = date }
        m.ingestScenePhase(.background)
        t = t.addingTimeInterval(20)
        m.lockWindowElapsed()
        #expect(got == Date(timeIntervalSinceReferenceDate: 0))
    }

    @Test("Without a known passcode, going to the background counts as locking")
    func noPasscodeFallsBackToLocking() {
        let m = monitor(passcode: false)
        m.ingestScenePhase(.background)
        m.lockWindowElapsed()
        #expect(m.posture == .closed)
    }

    @Test("Coming back releases it")
    func activeReleases() {
        let m = monitor(passcode: true)
        var t = Date(timeIntervalSinceReferenceDate: 0)
        m.now = { t }
        m.ingestScenePhase(.background)
        m.deviceLocked()
        t = t.addingTimeInterval(60)
        m.ingestScenePhase(.active)
        #expect(m.posture == .open)
    }

    @Test("A blip in the background decides nothing")
    func transientBackgroundIgnored() {
        let m = monitor(passcode: true)
        var t = Date(timeIntervalSinceReferenceDate: 0)
        m.now = { t }
        var postures: [HingeMonitor.Posture] = []
        m.onPosture = { p, _ in postures.append(p) }
        m.ingestScenePhase(.background)
        t = t.addingTimeInterval(0.5)
        m.ingestScenePhase(.active)
        #expect(postures == [.open])
    }

    @Test("Control Centre is ignored")
    func inactiveIsIgnored() {
        let m = monitor(passcode: true)
        m.ingestScenePhase(.background)
        m.deviceLocked()
        m.ingestScenePhase(.inactive)
        #expect(m.posture == .closed)
    }

    @Test("On a foldable, a lock changes nothing — the hinge still rules")
    func foldableLockIsNeutral() {
        let m = monitor(passcode: true)
        m.ingestHinge(isFoldable: true, posture: .closed)
        m.ingestScenePhase(.background)
        m.deviceLocked()
        #expect(m.posture == .closed)
    }

    @Test("On a foldable, leaving the app while shut is a release")
    func foldableLeavingReleases() {
        let m = monitor(passcode: true)
        m.ingestHinge(isFoldable: true, posture: .closed)
        m.ingestScenePhase(.background)
        m.lockWindowElapsed()
        #expect(m.posture == .open)
    }

    @Test("... and coming back while still shut restores the hinge's reading")
    func foldableReturnRestoresHinge() {
        let m = monitor(passcode: true)
        var t = Date(timeIntervalSinceReferenceDate: 0)
        m.now = { t }
        m.ingestHinge(isFoldable: true, posture: .closed)
        m.ingestScenePhase(.background)
        t = t.addingTimeInterval(5)
        m.ingestScenePhase(.active)
        #expect(m.posture == .closed)
    }

    @Test("Control Centre does not start an armed block")
    func controlCentreDoesNotStartArmedBlock() {
        let m = monitor(passcode: true)
        let h = Harness()
        h.arm(60)
        m.onPosture = { p, _ in h.handle(p) }
        m.ingestScenePhase(.inactive)

        #expect(h.phase == .armed)
    }

    @Test("... and does not break a running one")
    func controlCentreDoesNotBreakRunningBlock() {
        let m = monitor(passcode: true)
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 5)
        m.onPosture = { p, _ in h.handle(p) }
        m.ingestScenePhase(.inactive)

        #expect(h.phase == .running)
    }
}

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

        init(grace: Int = Prefs.defaultGraceSeconds) {
            UserDefaults.standard.set(grace, forKey: PrefKey.graceSeconds)
            let clock = Clock()
            self.clock = clock
            engine.now = { clock.t }
        }

        deinit { UserDefaults.standard.removeObject(forKey: PrefKey.graceSeconds) }

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

    @Test("An open-ended block never self-completes; it breaks when opened")
    func openEndedBreaksOnOpen() {
        let h = Harness()
        h.arm(0)
        h.handle(.closed)
        h.shut(until: 1800)
        h.handle(.open)
        h.awake(until: 1811)

        #expect(h.outcome == .broken)
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

    // MARK: - The lock path: scene phase

    @Test("Locking the screen commits the block")
    func backgroundCommits() {
        let monitor = HingeMonitor()
        monitor.ingestScenePhase(.background)
        #expect(monitor.posture == .closed)
    }

    @Test("Coming back releases it")
    func activeReleases() {
        let monitor = HingeMonitor()
        monitor.ingestScenePhase(.background)
        monitor.ingestScenePhase(.active)
        #expect(monitor.posture == .open)
    }

    @Test("Control Centre is ignored")
    func inactiveIsIgnored() {
        let monitor = HingeMonitor()
        monitor.ingestScenePhase(.background)
        monitor.ingestScenePhase(.inactive)
        #expect(monitor.posture == .closed)
    }

    @Test("On a foldable, scene phase is ignored entirely")
    func foldableIgnoresScenePhase() {
        let monitor = HingeMonitor()
        monitor.ingestHinge(isFoldable: true, posture: .open)
        monitor.ingestScenePhase(.background)
        #expect(monitor.posture == .open)
    }

    @Test("Control Centre does not start an armed block")
    func controlCentreDoesNotStartArmedBlock() {
        let monitor = HingeMonitor()
        let h = Harness()
        h.arm(60)

        let before = monitor.posture
        monitor.ingestScenePhase(.inactive)
        if monitor.posture != before { h.handle(monitor.posture) }

        #expect(h.phase == .armed)
    }

    @Test("... and does not break a running one")
    func controlCentreDoesNotBreakRunningBlock() {
        let monitor = HingeMonitor()
        let h = Harness()
        h.arm(60)
        h.handle(.closed)
        h.shut(until: 5)

        let before = monitor.posture
        monitor.ingestScenePhase(.inactive)
        if monitor.posture != before { h.handle(monitor.posture) }

        #expect(h.phase == .running)
    }
}

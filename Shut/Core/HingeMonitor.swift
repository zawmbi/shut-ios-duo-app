import Foundation
import Observation
import SwiftUI
import UIKit

/// The only hardware-aware type in the app.
///
/// Everything downstream consumes `posture` and `trigger`. Nothing else in the
/// codebase is allowed to ask what device it is running on — if you find
/// yourself writing a second `isFoldable` check somewhere, this abstraction is
/// wrong and should be widened instead.
@MainActor
@Observable
final class HingeMonitor {

    /// What the user physically does to commit to a block.
    enum Trigger {
        /// iPhone Duo: fold the phone shut.
        case fold
        /// Every other iPhone: lock the screen.
        case lock

        var verb: String {
            switch self {
            case .fold: "Fold to begin"
            case .lock: "Lock to begin"
            }
        }

        var committedNoun: String {
            switch self {
            case .fold: "folded"
            case .lock: "locked"
            }
        }

        var breakVerb: String {
            switch self {
            case .fold: "You opened it."
            case .lock: "You unlocked it."
            }
        }
    }

    /// Normalised across both hardware paths. On a non-foldable iPhone there is
    /// no `.partial` — the screen is either locked or it isn't.
    enum Posture: Equatable {
        case closed
        case partial
        case open

        /// Whether this posture counts as the user having committed.
        var isCommitted: Bool { self == .closed }
    }

    private(set) var isFoldable: Bool = false
    private(set) var posture: Posture = .open

    var trigger: Trigger { isFoldable ? .fold : .lock }

    /// Every posture change, with the moment it actually happened. A release
    /// discovered after the fact — the user left the app twenty seconds ago —
    /// is delivered with that earlier date, so grace is measured from when they
    /// left, not from when we worked it out.
    ///
    /// A closure rather than an observed property on purpose: decisions are made
    /// while the app is in the background, when SwiftUI is not rendering and an
    /// `onChange` would not run.
    @ObservationIgnored
    var onPosture: ((Posture, Date) -> Void)?

    @ObservationIgnored
    var now: () -> Date = { .now }

    /// The last posture the hinge itself reported, kept apart from `posture`
    /// so that a release inferred from leaving the app can be undone by the
    /// hinge's real reading when the user comes back.
    private var hingePosture: Posture = .open

    // MARK: Leaving the app

    /// How long, after going to the background, to wait for the device to
    /// report that it locked. With a passcode, iOS announces a lock through
    /// `protectedDataWillBecomeUnavailable` roughly ten seconds after it happens.
    static let lockWindow: Duration = .seconds(20)

    /// Shorter than this in the background is a blip, not a decision — a Duo
    /// swapping displays, a notification pulled down. Ignored.
    static let transientAway: TimeInterval = 1.5

    /// Latched on the first lock the device ever reports. Without a passcode
    /// iOS never reports a lock, so a lock cannot be told apart from leaving the
    /// app, and the old behaviour — going to the background counts as locking —
    /// is the only honest option left.
    private(set) var hasPasscode: Bool

    private let store: UserDefaults

    private var awaySince: Date?
    private var awayResolved = false
    private var lockWindowTask: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init(store: UserDefaults = .standard) {
        self.store = store
        hasPasscode = store.bool(forKey: PrefKey.passcodeSeen)
        Task { [weak self] in
            let locks = NotificationCenter.default.notifications(
                named: UIApplication.protectedDataWillBecomeUnavailableNotification
            )
            for await _ in locks {
                self?.deviceLocked()
            }
        }
    }

    // MARK: - Inputs

    /// Called by `HingeBridge` on iPhone Duo whenever a hinge is reported.
    ///
    /// `isFoldable` latches on. Once this device has produced a hinge it is a
    /// fold device for the rest of the process, and a later nil reading cannot
    /// downgrade it — see `ingestHingeUnavailable()`.
    func ingestHinge(isFoldable: Bool, posture: Posture) {
        if isFoldable { self.isFoldable = true }
        hingePosture = posture
        emit(posture, at: now())
    }

    /// Called when the hinge observer reports a nil hinge.
    ///
    /// This is deliberately *not* "the device stopped being foldable". Apple's
    /// `UIHingeInteraction` header documents nil as also meaning the observer
    /// has left a hierarchy that provides hinge updates, so on a Duo this can
    /// arrive mid-session. Posture is left untouched rather than guessed: a
    /// wrong `.open` here would break a block the user is still keeping.
    ///
    /// On a non-foldable iPhone `isFoldable` has never been set, so this is a
    /// no-op and the lock-based path stays in charge.
    func ingestHingeUnavailable() {
        // Intentionally empty. Documented above so nobody "fixes" it later.
    }

    /// Called on every device from the root view's scene-phase observer.
    ///
    /// Going to the background is ambiguous. It is either a lock, which is a
    /// commitment, or leaving the app for another one, which is the opposite.
    /// So nothing is decided on the spot: the app holds a short background task
    /// open and waits `lockWindow` for iOS to say the device locked.
    ///
    /// - Locked: on a plain iPhone that is the commit. On Duo it changes
    ///   nothing — the hinge still says what it says.
    /// - Not locked: the user left Shut. On both devices that is a release,
    ///   dated to the moment they left.
    ///
    /// `.inactive` alone is Control Centre, the app switcher or an incoming
    /// call, and is never a decision.
    func ingestScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background: wentAway()
        case .active:     cameBack()
        case .inactive:   break
        @unknown default: break
        }
    }

    // MARK: - Away

    private func wentAway() {
        guard awaySince == nil else { return }
        awaySince = now()
        awayResolved = false
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "shut.lock-window") { [weak self] in
            MainActor.assumeIsolated { self?.resolveAway(sawLock: false) }
        }
        lockWindowTask = Task { [weak self] in
            try? await Task.sleep(for: Self.lockWindow)
            guard !Task.isCancelled else { return }
            self?.lockWindowElapsed()
        }
    }

    /// iOS said the device locked. Internal rather than private so tests can
    /// stand in for the system notification.
    func deviceLocked() {
        if !hasPasscode {
            hasPasscode = true
            store.set(true, forKey: PrefKey.passcodeSeen)
        }
        resolveAway(sawLock: true)
    }

    /// The wait for a lock ran out without one. Internal for the same reason.
    func lockWindowElapsed() {
        resolveAway(sawLock: false)
    }

    private func resolveAway(sawLock: Bool) {
        defer { endBackgroundTask() }
        guard let since = awaySince, !awayResolved else { return }
        awayResolved = true
        lockWindowTask?.cancel()

        if sawLock || !hasPasscode {
            if !isFoldable { emit(.closed, at: since) }
        } else {
            emit(.open, at: since)
        }
    }

    private func cameBack() {
        defer { awaySince = nil }
        if let since = awaySince, !awayResolved {
            if now().timeIntervalSince(since) < Self.transientAway {
                awayResolved = true
                lockWindowTask?.cancel()
                endBackgroundTask()
            } else {
                resolveAway(sawLock: false)
            }
        }
        // Back in front. On Duo, restore whatever the hinge last reported, which
        // undoes a release inferred from leaving if the phone is still shut. On
        // every other iPhone, being in front means unlocked.
        emit(isFoldable ? hingePosture : .open, at: now())
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func emit(_ posture: Posture, at date: Date) {
        self.posture = posture
        onPosture?(posture, date)
    }
}

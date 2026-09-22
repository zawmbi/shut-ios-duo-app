import Foundation
import Observation
import SwiftUI

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

    // MARK: - Inputs

    /// Called by `HingeBridge` on iPhone Duo whenever a hinge is reported.
    ///
    /// `isFoldable` latches on. Once this device has produced a hinge it is a
    /// fold device for the rest of the process, and a later nil reading cannot
    /// downgrade it — see `ingestHingeUnavailable()`.
    func ingestHinge(isFoldable: Bool, posture: Posture) {
        if isFoldable { self.isFoldable = true }
        self.posture = posture
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
    /// On a foldable this is ignored: folding the phone shut moves the app to
    /// the outer display rather than backgrounding it, so scene phase is not a
    /// reliable proxy for the hinge and would fight `ingestHinge`.
    ///
    /// `.inactive` is deliberately not treated as committed. Locking the screen
    /// backgrounds the app, so `.background` is the signal we want; `.inactive`
    /// alone is Control Centre, the app switcher or an incoming call, and
    /// reading those as a fold would start blocks the user never started and
    /// break ones they never opened.
    func ingestScenePhase(_ phase: ScenePhase) {
        guard !isFoldable else { return }
        switch phase {
        case .active:     posture = .open
        case .background: posture = .closed
        case .inactive:   break
        @unknown default: break
        }
    }
}

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

    /// Called by `HingeBridge` on iPhone Duo. See the VERIFY banner in that file.
    func ingestHinge(isFoldable: Bool, posture: Posture) {
        self.isFoldable = isFoldable
        self.posture = posture
    }

    /// Called on every device from the root view's scene-phase observer.
    ///
    /// On a foldable this is ignored: folding the phone shut moves the app to
    /// the outer display rather than backgrounding it, so scene phase is not a
    /// reliable proxy for the hinge and would fight `ingestHinge`.
    func ingestScenePhase(_ phase: ScenePhase) {
        guard !isFoldable else { return }
        switch phase {
        case .active:               posture = .open
        case .inactive, .background: posture = .closed
        @unknown default:           posture = .open
        }
    }
}

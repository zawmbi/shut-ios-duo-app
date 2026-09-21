import Foundation
import Observation

/// Drives pixels, never state.
///
/// Every value the app persists is derived by subtracting stored `Date`s, so a
/// missed tick, a suspended process or a clock adjustment can't corrupt a
/// session. This exists only so SwiftUI has something to observe once a second.
@MainActor
@Observable
final class SessionClock {
    private(set) var now: Date = .now
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                await MainActor.run { self?.now = .now }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit { task?.cancel() }
}

#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// App Store screenshots, staged. Debug builds only — none of this is in an
/// archive.
///
/// Launch with `-screenshot <scene>` and the app comes up in that state over an
/// in-memory store of made-up history, with the engine's clock frozen so the
/// numbers hold still for the capture. Nothing it does touches the real store
/// or the real in-flight block.
///
/// The hinge is left alone: on Duo it still reports, so the copy says "Fold";
/// on every other iPhone it says "Lock". It just isn't wired to the engine, so
/// a posture can't move the staged block.
///
/// Theme, face, look and Pro come from the same launch arguments `@AppStorage`
/// reads, e.g. `-theme dusk -face.style sunburst -look.text serif -pro.cached YES`.
/// The appearance editor opens on the tab named by `-appearance.tab`.
enum ScreenshotStage: String {
    case home, running, grace, kept, history, settings, appearance

    static let current: ScreenshotStage? =
        UserDefaults.standard.string(forKey: "screenshot").flatMap(Self.init)

    /// A block that started at 10:14 today, so the times on screen read like a
    /// morning, whenever the capture happens.
    private static var blockStart: Date {
        Calendar.current.date(bySettingHour: 10, minute: 14, second: 0, of: .now) ?? .now
    }

    private static let target = 45 * 60

    /// Stands in for `engine.configure(context:)`, so the real in-flight block
    /// is never restored into a staged launch.
    @MainActor func stage(_ engine: SessionEngine, in context: ModelContext) {
        engine.store = UserDefaults(suiteName: "shut.screenshots") ?? .standard
        engine.store.removeObject(forKey: PrefKey.inFlight)
        engine.schedulesNotifications = false
        engine.configure(context: context)
        Self.seed(context)

        let start = Self.blockStart
        func at(_ offset: TimeInterval) { engine.now = { start.addingTimeInterval(offset) } }

        switch self {
        case .home, .history, .settings, .appearance:
            break
        case .running:
            // 18:42 left of 45 minutes.
            at(0)
            engine.arm(target: Self.target)
            engine.handle(posture: .closed)
            at(Double(Self.target) - (18 * 60 + 42))
        case .grace:
            at(0)
            engine.arm(target: Self.target)
            engine.handle(posture: .closed)
            at(26 * 60 + 18)
            engine.handle(posture: .open)
            at(26 * 60 + 18 + 0.6)
        case .kept:
            at(0)
            engine.arm(target: Self.target)
            engine.handle(posture: .closed)
            at(Double(Self.target) + 4)
            engine.tick()
        }
    }

    /// Sixteen days of mornings and afternoons, one of them broken, so the
    /// streak, today's total and the week and month figures all have something
    /// honest-looking to show.
    @MainActor private static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let labels = ["Thesis", "Reading", "Deep work", nil, "Thesis", "Spanish", nil]

        func add(day: Int, hour: Int, minute: Int, length: Int, outcome: SessionOutcome = .completed, label: String? = nil) {
            guard let dayStart = cal.date(byAdding: .day, value: -day, to: today),
                  let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) else { return }
            let session = Session(startedAt: start, targetSeconds: length * 60)
            let kept = outcome == .completed ? length : length / 2 + 3
            session.endedAt = start.addingTimeInterval(Double(kept * 60))
            session.outcome = outcome
            session.interruptions = outcome == .completed ? 0 : 1
            session.label = label
            context.insert(session)
        }

        // Today, before the staged block.
        add(day: 0, hour: 8, minute: 2, length: 25, label: "Reading")
        add(day: 0, hour: 8, minute: 40, length: 60, label: "Thesis")

        for day in 1...16 {
            let label = labels[day % labels.count]
            add(day: day, hour: 9, minute: 5 + day % 4 * 7, length: [45, 60, 25, 90][day % 4], label: label)
            if day % 3 != 0 {
                add(day: day, hour: 14, minute: 30, length: [25, 45][day % 2], label: labels[(day + 2) % labels.count])
            }
            if day == 4 {
                add(day: day, hour: 16, minute: 10, length: 45, outcome: .broken)
            }
        }
        try? context.save()
    }
}
#endif

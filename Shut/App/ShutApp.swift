import SwiftUI
import SwiftData
import UserNotifications

@main
struct ShutApp: App {
    @State private var engine: SessionEngine
    @State private var hinge: HingeMonitor
    @State private var clock = SessionClock()
    @State private var pro = Entitlements()

    private let container: ModelContainer

    init() {
        let schema = Schema([Session.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        // Configured here, before any view exists, so a block the last process
        // left in flight is restored before Home can arm a new one over it.
        let engine = SessionEngine()
        engine.configure(context: container.mainContext)
        _engine = State(initialValue: engine)

        // Wired before the first view too: the hinge reports once on appear, and
        // that first reading — a phone already shut — must not be dropped.
        let hinge = HingeMonitor()
        hinge.onPosture = { [engine] posture, date in
            engine.handle(posture: posture, at: date)
        }
        _hinge = State(initialValue: hinge)
        UNUserNotificationCenter.current().delegate = ForegroundNotifications.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(hinge)
                .environment(clock)
                .environment(pro)
                .task {
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])
                    await pro.load()
                }
        }
        .modelContainer(container)

        // ─────────────────────────────────────────────────────────────────────
        //  THE OUTER DISPLAY — answered in Milestone 0, 2026-09-21.
        //
        //  There is no second scene to add here, and that is the good outcome.
        //  iOS 27.1 has no outer-display scene API: the system relocates this
        //  single WindowGroup between the Duo's two integrated displays when
        //  the hinge crosses the swap boundary. Verified on the simulator —
        //  while shut, the app is alive and drawing on the cover display, and
        //  reports exactly one connected scene and one UIScreen.
        //
        //  So "inner face vs outer face" is a view-level branch on
        //  HingeMonitor.posture inside RootView, not a scene-level decision,
        //  and Views/Outer/TimerFaceView is presented like any other view.
        //
        //  Plan B (local notifications, no live face) is NOT needed. See
        //  FINDINGS.md §2 for the measurements.
        // ─────────────────────────────────────────────────────────────────────
    }
}

/// On Duo the app is in front on the cover display when a block ends, and iOS
/// drops a foreground app's notifications unless it says otherwise — which
/// would silence the end-of-block sound exactly where it matters.
final class ForegroundNotifications: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotifications()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

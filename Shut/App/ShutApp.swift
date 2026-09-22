import SwiftUI
import SwiftData
import UserNotifications

@main
struct ShutApp: App {
    @State private var engine = SessionEngine()
    @State private var hinge = HingeMonitor()
    @State private var clock = SessionClock()
    @State private var pro = Entitlements()

    private let container: ModelContainer = {
        let schema = Schema([Session.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(hinge)
                .environment(clock)
                .environment(pro)
                .task {
                    engine.configure(context: container.mainContext)
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

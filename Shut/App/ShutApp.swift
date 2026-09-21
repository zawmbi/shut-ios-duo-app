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
        //  ⚠️  THE OUTER DISPLAY — Milestone 0, and the reason this app exists
        //
        //  On iPhone Duo the app must keep running when the phone is folded
        //  shut, and present the timer face on the outer display rather than
        //  the inner one. The outer display stays lit when the phone is closed
        //  — it is not a laptop lid — so this should work, but the exact scene
        //  API is unconfirmed. Watch Apple's tech talk "Leverage multiple
        //  displays and scenes on iPhone Duo" (tech-talks/111464), find the
        //  real API, and replace this comment with it.
        //
        //  PLAN B, if there is no usable outer-display scene: keep the single
        //  WindowGroup, rely on the scheduled local notification to signal the
        //  end of a block, and recompute everything from `startedAt` when the
        //  app returns to the foreground. The engine already works this way —
        //  it never trusts a timer — so Plan B is a deletion, not a rewrite.
        //  Make that call in the first hour. Do not write UI against an API you
        //  have not seen compile.
        // ─────────────────────────────────────────────────────────────────────
    }
}

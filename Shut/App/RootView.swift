import SwiftUI

/// Routes the inner display on engine phase. The outer display is handled
/// separately in `ShutApp` and always shows the timer face.
struct RootView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(SessionClock.self) private var clock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch engine.phase {
            case .idle, .armed:
                HomeView()
            case .running:
                // On Duo this is only reached transiently; on every other
                // iPhone it is what the user sees the instant before the screen
                // locks, and what greets them on unlock.
                TimerFaceView()
            case .grace:
                InterruptView()
            case .complete, .broken:
                ResultView()
            }
        }
        .animation(.snappy(duration: 0.25), value: engine.phase)
        .preferredColorScheme(Theme.scheme)
        .hingeAware(hinge)
        .onChange(of: scenePhase) { _, phase in
            hinge.ingestScenePhase(phase)
        }
        .onChange(of: hinge.posture) { _, posture in
            engine.handle(posture: posture)
        }
        .onChange(of: clock.now) { _, _ in
            engine.tick()
        }
        .onAppear { clock.start() }
    }
}

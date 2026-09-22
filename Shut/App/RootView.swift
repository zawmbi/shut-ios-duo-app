import SwiftUI

/// Routes on engine phase, for whichever display the app is currently on.
///
/// There is no separate outer-display view tree. On Duo the system relocates
/// the app's single scene to the cover display when the phone is shut, so the
/// branch below is all the routing there is — `TimerFaceView` on `.running` is
/// what the cover display shows. See `FINDINGS.md` §2.
struct RootView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(SessionClock.self) private var clock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch engine.phase {
            case .idle, .armed:
                HomeView()
            case .running:
                // On Duo this is the cover-display face, shown for the whole
                // block. On every other iPhone it is what the user sees the
                // instant before the screen locks, and what greets them on
                // unlock. Same view, same state, different display.
                TimerFaceView()
            case .grace:
                InterruptView()
            case .complete, .broken:
                ResultView()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: engine.phase)
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

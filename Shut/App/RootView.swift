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
    @Environment(Entitlements.self) private var pro

    @AppStorage(PrefKey.theme) private var themeRaw: String = ThemeID.walnut.rawValue

    /// A Pro theme left in defaults after a refund falls back to Walnut, the
    /// same rule the timer faces follow.
    private var palette: Palette {
        let chosen = ThemeID(rawValue: themeRaw) ?? .walnut
        return (chosen.isPro && !pro.isPro) ? ThemeID.walnut.palette : chosen.palette
    }

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
        .environment(\.palette, palette)
        .tint(palette.primary)
        .preferredColorScheme(palette.scheme)
        .hingeAware(hinge)
        .onChange(of: scenePhase) { _, phase in
            hinge.ingestScenePhase(phase)
        }
        .onChange(of: clock.now) { _, _ in
            engine.tick()
        }
        .onAppear { clock.start() }
    }
}

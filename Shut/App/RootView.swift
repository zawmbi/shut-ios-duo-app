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
    @AppStorage(PrefKey.customColors) private var customJSON: String = ""
    @AppStorage(PrefKey.textFace) private var textFace: TextFace = .sans
    @AppStorage(PrefKey.numeralFace) private var numeralFace: NumeralFace = .rounded
    @AppStorage(PrefKey.numeralWeight) private var numeralWeight: NumeralWeight = .bold
    @AppStorage(PrefKey.corners) private var corners: Corners = .soft

    /// Pro colours, faces and type left in defaults after a refund fall back
    /// to Classic — the same rule the timer faces follow.
    private var palette: Palette {
        Appearance.palette(themeRaw: themeRaw, customJSON: customJSON, isPro: pro.isPro)
    }

    private var look: Look {
        Appearance.look(
            Look(text: textFace, numerals: numeralFace, weight: numeralWeight, corners: corners),
            isPro: pro.isPro
        )
    }

    @ViewBuilder private var phaseView: some View {
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

    var body: some View {
        Group {
            #if DEBUG
            if ScreenshotStage.current == .appearance {
                NavigationStack { AppearanceView() }
            } else {
                phaseView
            }
            #else
            phaseView
            #endif
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: engine.phase)
        .environment(\.palette, palette)
        .environment(\.look, look)
        .fontDesign(look.text.design)
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

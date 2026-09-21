import SwiftUI

/// What the outer display shows while the phone is shut.
///
/// Deliberately dark where the rest of the app is cream: this face is read in a
/// dark room on a display that stays lit for the length of a block, so the ink
/// ground is both a battery decision and a legibility one.
struct TimerFaceView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(SessionClock.self) private var clock
    @Environment(Entitlements.self) private var pro

    @AppStorage(PrefKey.faceStyle) private var faceRaw: String = FaceStyle.ring.rawValue

    private var style: FaceStyle {
        let chosen = FaceStyle(rawValue: faceRaw) ?? .ring
        return (chosen.isPro && !pro.isPro) ? .ring : chosen
    }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            GeometryReader { proxy in
                // The outer display carries a camera occlusion; framework views
                // work around it automatically, but this face is custom, so it
                // asks where the reserved regions are and keeps clear of them.
                let inset = ReservedInsets.resolve(proxy)

                VStack(spacing: 18) {
                    switch style {
                    case .ring:   ring
                    case .digits: digits
                    case .bar:    bar
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .padding(inset)
            }
        }
        .onChange(of: clock.now) { _, _ in engine.tick() }
        .onAppear { clock.start() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var timeText: String {
        if let remaining = engine.remaining {
            return Stats.clock(remaining)
        }
        return Stats.clock(engine.elapsed)
    }

    private var ring: some View {
        ZStack {
            RingProgress(
                progress: engine.progress,
                lineWidth: 8,
                indeterminate: engine.targetSeconds == 0
            )
            .frame(width: 168, height: 168)

            VStack(spacing: 2) {
                Text(timeText)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text(engine.targetSeconds == 0 ? "elapsed" : "left")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.cream.opacity(0.45))
            }
        }
    }

    private var digits: some View {
        Text(timeText)
            .font(.system(size: 76, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.cream)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(countsDown: true))
    }

    private var bar: some View {
        VStack(spacing: 14) {
            Text(timeText)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.cream)
                .monospacedDigit()
            GeometryReader { p in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cream.opacity(0.15))
                    Capsule()
                        .fill(Theme.greenLight)
                        .frame(width: max(4, p.size.width * engine.progress))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 28)
        }
    }
}

/// Keeps custom drawing clear of the fold and the cameras.
///
/// VERIFY (Milestone 0): confirm the `reservedRegions` signature and the kind
/// case names against the SDK. Until `-D DUO_SDK` is set this returns zero,
/// which is correct on every non-foldable iPhone.
enum ReservedInsets {
    static func resolve(_ proxy: GeometryProxy) -> EdgeInsets {
        #if DUO_SDK
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .occlusion)
            let top = regions.map(\.frame.maxY).max() ?? 0
            return EdgeInsets(top: top, leading: 0, bottom: 0, trailing: 0)
        }
        #endif
        return EdgeInsets()
    }
}

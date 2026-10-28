import SwiftUI

/// What the outer display shows while the phone is shut.
///
/// Always dark, whatever the theme: this face is read in a dark room on a
/// display that stays lit for the length of a block, so the dark ground is both
/// a battery decision and a legibility one. Each theme brings its own face
/// palette; Dusk's is true black.
struct TimerFaceView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(SessionClock.self) private var clock
    @Environment(Entitlements.self) private var pro
    @Environment(\.palette) private var palette

    @AppStorage(PrefKey.faceStyle) private var faceRaw: String = FaceStyle.ring.rawValue
    @AppStorage(PrefKey.encouragement) private var encourage = false

    private var style: FaceStyle {
        let chosen = FaceStyle(rawValue: faceRaw) ?? .ring
        return (chosen.isPro && !pro.isPro) ? .ring : chosen
    }

    var body: some View {
        ZStack {
            palette.face.ignoresSafeArea()

            GeometryReader { proxy in
                // The cover display reported no reserved regions when measured
                // (FINDINGS.md §3); its status bar arrives as safe area, which
                // the GeometryReader already respects. This stays so a region
                // that does turn up on hardware is kept clear of.
                let inset = ReservedInsets.resolve(proxy)

                VStack(spacing: 28) {
                    FaceArt(
                        style: style,
                        progress: engine.progress,
                        indeterminate: engine.targetSeconds == 0,
                        time: timeText,
                        caption: caption
                    )
                    // scaleEffect doesn't take up room, so a scaled face
                    // reserves its own height or the caption below would
                    // sit under it.
                    .scaleEffect(Self.scale(for: proxy.size))
                    .frame(height: Self.scale(for: proxy.size) > 1 ? 280 * Self.scale(for: proxy.size) : nil)

                    if encourage {
                        Text(encouragement)
                            .font(.plain(.subheadline, .medium))
                            .foregroundStyle(palette.faceSoft)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                            .transition(.opacity)
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
        // The face is one number drawn four ways. As written the drawing is
        // decorative to VoiceOver, so the whole face becomes a single element
        // that reads the time remaining and re-reads it as it changes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenTime)
        .accessibilityAddTraits(.updatesFrequently)
        // Almost no text, a small display, and a caption that must not wrap:
        // the face scales a little and then stops.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private var encouragement: String {
        Encouragement.line(
            for: .running(progress: engine.progress, openEnded: engine.targetSeconds == 0),
            seed: engine.startedAt
        )
    }

    private var spokenTime: String {
        let time = engine.remaining.map { "\(Stats.spoken($0)) left" }
            ?? "\(Stats.spoken(engine.elapsed)) elapsed"
        return encourage ? "\(time). \(encouragement)" : time
    }

    private var timeText: String {
        if let remaining = engine.remaining {
            return Stats.clock(remaining)
        }
        return Stats.clock(engine.elapsed)
    }

    private var caption: String { engine.targetSeconds == 0 ? "Elapsed" : "Left" }

    /// The faces are drawn for a phone. Any screen bigger than the largest
    /// iPhone gets them scaled up to match; nothing smaller changes.
    static func scale(for size: CGSize) -> CGFloat {
        max(1, min(size.width / 440, size.height / 700))
    }
}

/// One face, drawn from plain values rather than the engine, so the appearance
/// editor can show every face without a block running.
struct FaceArt: View {
    let style: FaceStyle
    let progress: Double
    let indeterminate: Bool
    let time: String
    let caption: String

    @Environment(\.palette) private var palette

    var body: some View {
        switch style {
        case .ring:     ring
        case .sunburst: sunburst
        case .digits:   digits
        case .bar:      bar
        case .dots:     dots
        case .hairline: hairline
        }
    }

    private func captionText() -> some View {
        Text(caption)
            .font(.plain(.caption2, .bold))
            .tracking(2.4)
            .textCase(.uppercase)
            .foregroundStyle(palette.faceSoft)
    }

    private func numerals(_ size: CGFloat, color: Color? = nil) -> some View {
        Text(time)
            .numeralFont(size)
            .foregroundStyle(color ?? palette.faceInk)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .contentTransition(.numericText(countsDown: true))
    }

    private var ring: some View {
        ZStack {
            RingProgress(
                progress: progress,
                indeterminate: indeterminate,
                track: palette.faceTrack,
                fill: palette.faceAccent,
                ticks: palette.faceSoft.opacity(0.6)
            )
            .frame(width: 236, height: 236)

            VStack(spacing: 4) {
                numerals(44)
                captionText()
            }
            .padding(.horizontal, 44)
        }
    }

    private var sunburst: some View {
        ZStack {
            Sunburst(
                progress: progress,
                indeterminate: indeterminate,
                lit: palette.faceAccent,
                unlit: palette.faceTrack,
                hub: palette.faceAccent2
            )
            .frame(width: 260, height: 260)

            VStack(spacing: 2) {
                numerals(34, color: palette.face)
                Text(caption)
                    .font(.plain(.caption2, .heavy))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.face.opacity(0.7))
            }
            .frame(width: 124)
        }
    }

    private var digits: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(palette.faceAccent).frame(width: 10, height: 10)
                Circle().fill(palette.faceAccent2).frame(width: 10, height: 10)
                Rectangle().fill(palette.faceTrack).frame(height: 2)
            }
            .frame(width: 200)
            numerals(80)
            captionText()
        }
        .padding(.horizontal, 20)
    }

    /// Twelve discs round the time, filled clockwise.
    private var dots: some View {
        let count = 12
        let lit = indeterminate ? count : Int((progress * Double(count)).rounded(.up))
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i < lit ? (i.isMultiple(of: 3) ? palette.faceAccent2 : palette.faceAccent) : palette.faceTrack)
                    .frame(width: 26, height: 26)
                    .offset(y: -110)
                    .rotationEffect(.degrees(Double(i) / Double(count) * 360))
            }
            VStack(spacing: 4) {
                numerals(46)
                captionText()
            }
            .padding(.horizontal, 60)
        }
        .frame(width: 250, height: 250)
        .accessibilityHidden(true)
    }

    /// A single fine line and a bead riding it, with the time large inside.
    private var hairline: some View {
        let end = indeterminate ? 1 : max(0.001, min(1, progress))
        return ZStack {
            Circle()
                .stroke(palette.faceTrack, lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: end)
                .stroke(palette.faceAccent, lineWidth: 1.5)
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(palette.faceAccent2)
                .frame(width: 10, height: 10)
                .offset(y: -120)
                .rotationEffect(.degrees(end * 360))
            VStack(spacing: 10) {
                numerals(56)
                Rectangle().fill(palette.faceSoft).frame(width: 28, height: 1)
                captionText()
            }
            .padding(.horizontal, 36)
        }
        .frame(width: 240, height: 240)
    }

    /// Twelve flat tiles, filled left to right.
    private var bar: some View {
        let segments = 12
        let lit = indeterminate
            ? segments
            : Int((progress * Double(segments)).rounded(.up))
        return VStack(spacing: 18) {
            numerals(52)
            HStack(spacing: 4) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit
                              ? (i.isMultiple(of: 4) ? palette.faceAccent2 : palette.faceAccent)
                              : palette.faceTrack)
                        .frame(height: 22)
                }
            }
            .frame(maxWidth: 260)
            .padding(.horizontal, 28)
            captionText()
        }
    }
}

/// Keeps custom drawing clear of the fold and the cameras.
///
/// Signature verified against the iOS 27.1 SDK (FINDINGS.md §3). Without
/// `-D DUO_SDK` this returns zero, which is correct on every non-foldable iPhone.
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

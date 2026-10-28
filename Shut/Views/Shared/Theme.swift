import SwiftUI

/// The app's colour themes.
///
/// Mid-century in spirit: warm paper grounds, flat blocks of teal, mustard and
/// rust, no gradients and no shadows. Each theme carries two palettes — one for
/// the inner display, and one for the face the cover display shows while the
/// phone is shut, which is always dark because it is read in a dim room on a
/// display that stays lit for the length of a block.
enum ThemeID: String, CaseIterable, Identifiable {
    case walnut, avocado, atomic, dusk
    // Each style's own palette. Any style can wear any of them.
    case graphite, blossom, noir, glacier, sunset
    var id: String { rawValue }

    var display: String { rawValue.capitalized }

    /// Free tier gets Walnut only, the same rule as the timer faces.
    var isPro: Bool { self != .walnut }

    var palette: Palette {
        switch self {
        case .walnut:   .walnut
        case .avocado:  .avocado
        case .atomic:   .atomic
        case .dusk:     .dusk
        case .graphite: .graphite
        case .blossom:  .blossom
        case .noir:     .noir
        case .glacier:  .glacier
        case .sunset:   .sunset
        }
    }
}

struct Palette: Equatable {
    // Inner display
    var paper: Color        // the ground
    var panel: Color        // cards, unselected tiles
    var ink: Color
    var inkSoft: Color
    var rule: Color
    var primary: Color      // selected tiles, the main button, kept time
    var onPrimary: Color    // text on `primary`
    var primaryText: Color  // `primary`'s hue at a contrast that small text can use
    var secondary: Color    // decorative shapes only, never text
    var tertiary: Color     // decorative shapes only, never text
    var scheme: ColorScheme

    // Cover display
    var face: Color
    var faceInk: Color
    var faceSoft: Color
    var faceTrack: Color
    var faceAccent: Color
    var faceAccent2: Color
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255
        )
    }
}

extension Palette {
    /// Teal, mustard and rust on cream. The default, and free.
    static let walnut = Palette(
        paper: Color(hex: 0xF2EADB), panel: Color(hex: 0xE6DAC3),
        ink: Color(hex: 0x2A2119), inkSoft: Color(hex: 0x6B5D4E), rule: Color(hex: 0xD6C8AE),
        primary: Color(hex: 0x2E6B66), onPrimary: Color(hex: 0xF2EADB), primaryText: Color(hex: 0x2E6B66),
        secondary: Color(hex: 0xD69E2E), tertiary: Color(hex: 0xC4532F),
        scheme: .light,
        face: Color(hex: 0x221A13), faceInk: Color(hex: 0xF2EADB), faceSoft: Color(hex: 0xA8998A),
        faceTrack: Color(hex: 0x3A2E24), faceAccent: Color(hex: 0xD69E2E), faceAccent2: Color(hex: 0xC4532F)
    )

    /// Olive, harvest gold and rust on a greener paper.
    static let avocado = Palette(
        paper: Color(hex: 0xEEEBD9), panel: Color(hex: 0xE0DCC2),
        ink: Color(hex: 0x26281C), inkSoft: Color(hex: 0x5E6150), rule: Color(hex: 0xCFCAAE),
        primary: Color(hex: 0x5A6824), onPrimary: Color(hex: 0xEEEBD9), primaryText: Color(hex: 0x5A6824),
        secondary: Color(hex: 0xD9A43A), tertiary: Color(hex: 0xA8472A),
        scheme: .light,
        face: Color(hex: 0x1C1E14), faceInk: Color(hex: 0xEEEBD9), faceSoft: Color(hex: 0x9A9C84),
        faceTrack: Color(hex: 0x33362A), faceAccent: Color(hex: 0xB5C25A), faceAccent2: Color(hex: 0xD9A43A)
    )

    /// Orange, turquoise and yellow on white, with a navy ink.
    static let atomic = Palette(
        paper: Color(hex: 0xF6F2E9), panel: Color(hex: 0xE9E3D5),
        ink: Color(hex: 0x1C2430), inkSoft: Color(hex: 0x566070), rule: Color(hex: 0xD5CFC1),
        primary: Color(hex: 0xE0662F), onPrimary: Color(hex: 0x1C2430), primaryText: Color(hex: 0xB0461A),
        secondary: Color(hex: 0x2A9D8F), tertiary: Color(hex: 0xF2C14E),
        scheme: .light,
        face: Color(hex: 0x131B26), faceInk: Color(hex: 0xF6F2E9), faceSoft: Color(hex: 0x8C96A6),
        faceTrack: Color(hex: 0x26303F), faceAccent: Color(hex: 0xF08A4B), faceAccent2: Color(hex: 0x3CC2B0)
    )

    /// Dark all the way through. Its face is true black, which a cover display
    /// shows as off.
    static let dusk = Palette(
        paper: Color(hex: 0x1B1815), panel: Color(hex: 0x2A2622),
        ink: Color(hex: 0xEFE6D6), inkSoft: Color(hex: 0xA69A88), rule: Color(hex: 0x3B352F),
        primary: Color(hex: 0xD69E2E), onPrimary: Color(hex: 0x1B1815), primaryText: Color(hex: 0xE0B04E),
        secondary: Color(hex: 0x3F8F87), tertiary: Color(hex: 0xC4532F),
        scheme: .dark,
        face: .black, faceInk: Color(hex: 0xEFE6D6), faceSoft: Color(hex: 0x8A7F70),
        faceTrack: Color(hex: 0x241F1A), faceAccent: Color(hex: 0xD69E2E), faceAccent2: Color(hex: 0x3F8F87)
    )

    /// Technical. Instrument grey with a signal orange.
    static let graphite = Palette(
        paper: Color(hex: 0xEDEEEA), panel: Color(hex: 0xDFE1DC),
        ink: Color(hex: 0x15181B), inkSoft: Color(hex: 0x5A6068), rule: Color(hex: 0xCDD0CB),
        primary: Color(hex: 0xFF5A1F), onPrimary: Color(hex: 0x15181B), primaryText: Color(hex: 0xA8380A),
        secondary: Color(hex: 0x2F80ED), tertiary: Color(hex: 0xFFB800),
        scheme: .light,
        face: Color(hex: 0x0E1012), faceInk: Color(hex: 0xE8EAE6), faceSoft: Color(hex: 0x7D848C),
        faceTrack: Color(hex: 0x22262B), faceAccent: Color(hex: 0xFF5A1F), faceAccent2: Color(hex: 0x2F80ED)
    )

    /// Cute. Pink, mint and lilac on a blush paper.
    static let blossom = Palette(
        paper: Color(hex: 0xFFF1F3), panel: Color(hex: 0xFBDDE3),
        ink: Color(hex: 0x3A2230), inkSoft: Color(hex: 0x85606F), rule: Color(hex: 0xF2C9D2),
        primary: Color(hex: 0xE86A92), onPrimary: Color(hex: 0x3A2230), primaryText: Color(hex: 0xB83B65),
        secondary: Color(hex: 0xA8D8C8), tertiary: Color(hex: 0xC7B3F0),
        scheme: .light,
        face: Color(hex: 0x2A1B26), faceInk: Color(hex: 0xFFE9EE), faceSoft: Color(hex: 0xB892A3),
        faceTrack: Color(hex: 0x3F2A38), faceAccent: Color(hex: 0xFF8FB1), faceAccent2: Color(hex: 0xA8E6CF)
    )

    /// Chic. Black on ivory, with gold and blush.
    static let noir = Palette(
        paper: Color(hex: 0xF7F3EE), panel: Color(hex: 0xECE5DC),
        ink: Color(hex: 0x111111), inkSoft: Color(hex: 0x6E6862), rule: Color(hex: 0xDDD5CA),
        primary: Color(hex: 0x111111), onPrimary: Color(hex: 0xF7F3EE), primaryText: Color(hex: 0x111111),
        secondary: Color(hex: 0xC9A96E), tertiary: Color(hex: 0xD9B8B0),
        scheme: .light,
        face: Color(hex: 0x0A0A0A), faceInk: Color(hex: 0xF7F3EE), faceSoft: Color(hex: 0x8F877E),
        faceTrack: Color(hex: 0x1E1D1B), faceAccent: Color(hex: 0xC9A96E), faceAccent2: Color(hex: 0xD9B8B0)
    )

    /// Cool. Deep teal and ice blue.
    static let glacier = Palette(
        paper: Color(hex: 0xEAF1F5), panel: Color(hex: 0xD9E5EC),
        ink: Color(hex: 0x0F2230), inkSoft: Color(hex: 0x4C6475), rule: Color(hex: 0xC5D5DF),
        primary: Color(hex: 0x1C6E8C), onPrimary: Color(hex: 0xEAF1F5), primaryText: Color(hex: 0x1C6E8C),
        secondary: Color(hex: 0x7FC8E0), tertiary: Color(hex: 0x2B3F8C),
        scheme: .light,
        face: Color(hex: 0x0B1620), faceInk: Color(hex: 0xE6F1F7), faceSoft: Color(hex: 0x7F95A5),
        faceTrack: Color(hex: 0x1A2A38), faceAccent: Color(hex: 0x5CC8F0), faceAccent2: Color(hex: 0x8A9CFF)
    )

    /// Retro. Seventies orange, gold and olive on a sand paper.
    static let sunset = Palette(
        paper: Color(hex: 0xF5E6CC), panel: Color(hex: 0xEBD4AE),
        ink: Color(hex: 0x3B2314), inkSoft: Color(hex: 0x7A5A42), rule: Color(hex: 0xDEC59C),
        primary: Color(hex: 0xB8461A), onPrimary: Color(hex: 0xF5E6CC), primaryText: Color(hex: 0x9C3A14),
        secondary: Color(hex: 0xE8A33D), tertiary: Color(hex: 0x6B8E4E),
        scheme: .light,
        face: Color(hex: 0x241509), faceInk: Color(hex: 0xF5E6CC), faceSoft: Color(hex: 0xA88F72),
        faceTrack: Color(hex: 0x3A2617), faceAccent: Color(hex: 0xF08A3C), faceAccent2: Color(hex: 0xE8C547)
    )
}

extension EnvironmentValues {
    /// Set once, in `RootView`, from the stored preference and the entitlement.
    @Entry var palette: Palette = .walnut
}

extension Font {
    /// The app's type scale.
    ///
    /// `Font.system(size:)` ignores Dynamic Type entirely, so every piece of
    /// real text goes through a text style instead. The big numerals on the
    /// timer, interrupt and result screens keep a fixed size on purpose: they
    /// are already far larger than any Dynamic Type step, and each one carries
    /// an accessibility label that reads the time aloud.
    ///
    /// No design is named here on purpose: `RootView` sets `.fontDesign` from
    /// the chosen text face, and an explicit design would override it. Timer
    /// numerals have their own face — see `View.numeralFont(_:)`.
    static func plain(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, weight: weight)
    }
}

/// Small uppercase label, used for every secondary line in the app.
private struct LabelStyle: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.look) private var look
    func body(content: Content) -> some View {
        content
            .font(.plain(.caption2, .bold))
            .tracking(look.text.labelTracking)
            .textCase(look.text.labelUppercase ? .uppercase : nil)
            .foregroundStyle(palette.inkSoft)
    }
}

private struct PaperBackground: ViewModifier {
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content.background(palette.paper.ignoresSafeArea())
    }
}

extension Text {
    func labelStyle() -> some View { modifier(LabelStyle()) }
}

extension View {
    func paperBackground() -> some View { modifier(PaperBackground()) }

    /// Holds content to a width that reads well, centred. Only screens wider
    /// than this notice — iPad, and the Duo's inner display; every iPhone is
    /// narrower. A width, not a device check.
    func readableWidth(_ max: CGFloat = 640) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}

/// A wordmark-sized emblem: a half disc folded down over a full one. The
/// app's one decorative motif, reused in the header and on the empty states.
struct FoldMark: View {
    var size: CGFloat = 26
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(palette.secondary)
                .frame(width: size, height: size)
            HalfDisc()
                .fill(palette.primary)
                .frame(width: size, height: size / 2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The top half of a circle, filling its frame.
struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        p.move(to: CGPoint(x: center.x - r, y: center.y))
        p.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.closeSubpath()
        return p
    }
}

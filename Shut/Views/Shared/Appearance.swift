import SwiftUI
import UIKit

// MARK: - Components

/// The typeface for everything that isn't a timer numeral.
enum TextFace: String, CaseIterable, Identifiable {
    case sans, rounded, serif, mono
    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .sans:    .default
        case .rounded: .rounded
        case .serif:   .serif
        case .mono:    .monospaced
        }
    }

    var display: String {
        switch self {
        case .sans:    "System"
        case .rounded: "Rounded"
        case .serif:   "Serif"
        case .mono:    "Mono"
        }
    }

    /// Rounded is the soft face, and its labels drop the capitals.
    var labelUppercase: Bool { self != .rounded }

    /// Small uppercase labels are tracked wide; how wide suits the face.
    var labelTracking: CGFloat {
        switch self {
        case .sans:    2
        case .rounded: 1.4
        case .serif:   2.6
        case .mono:    1
        }
    }
}

/// The typeface for the timer numerals, on every screen that shows one.
enum NumeralFace: String, CaseIterable, Identifiable {
    case rounded, sans, serif, mono
    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .rounded: .rounded
        case .sans:    .default
        case .serif:   .serif
        case .mono:    .monospaced
        }
    }

    var display: String {
        switch self {
        case .rounded: "Rounded"
        case .sans:    "System"
        case .serif:   "Serif"
        case .mono:    "Mono"
        }
    }
}

enum NumeralWeight: String, CaseIterable, Identifiable {
    case light, regular, bold, heavy
    var id: String { rawValue }

    var weight: Font.Weight {
        switch self {
        case .light:   .light
        case .regular: .regular
        case .bold:    .bold
        case .heavy:   .heavy
        }
    }

    var display: String { rawValue.capitalized }
}

enum Corners: String, CaseIterable, Identifiable {
    case sharp, soft, round
    var id: String { rawValue }

    var radius: CGFloat {
        switch self {
        case .sharp: 0
        case .soft:  6
        case .round: 16
        }
    }

    var display: String { rawValue.capitalized }
}

/// Type and shape, read by every view through `\.look`. Colour stays in
/// `\.palette`; the two are chosen separately and resolved together in
/// `RootView`.
struct Look: Equatable {
    var text: TextFace
    var numerals: NumeralFace
    var weight: NumeralWeight
    var corners: Corners

    /// The original look, and the only one free.
    static let classic = Look(text: .sans, numerals: .rounded, weight: .bold, corners: .soft)
}

extension EnvironmentValues {
    @Entry var look: Look = .classic
}

extension View {
    /// Timer numerals in the chosen numeral face. Fixed sizes on purpose — see
    /// `Font.plain`.
    func numeralFont(_ size: CGFloat) -> some View {
        modifier(NumeralFont(size: size))
    }
}

private struct NumeralFont: ViewModifier {
    let size: CGFloat
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: look.weight.weight, design: look.numerals.design))
    }
}

// MARK: - Styles

/// A starting point: one tap sets every component, and each can be changed
/// afterwards. Classic is the app as it shipped, and free.
enum StyleID: String, CaseIterable, Identifiable {
    case classic, technical, cute, chic, cool, retro
    var id: String { rawValue }

    var display: String { rawValue.capitalized }

    var isPro: Bool { self != .classic }

    var look: Look {
        switch self {
        case .classic:   .classic
        case .technical: Look(text: .mono, numerals: .mono, weight: .regular, corners: .sharp)
        case .cute:      Look(text: .rounded, numerals: .rounded, weight: .heavy, corners: .round)
        case .chic:      Look(text: .serif, numerals: .serif, weight: .light, corners: .sharp)
        case .cool:      Look(text: .sans, numerals: .sans, weight: .bold, corners: .round)
        case .retro:     Look(text: .serif, numerals: .serif, weight: .heavy, corners: .soft)
        }
    }

    var theme: ThemeID {
        switch self {
        case .classic:   .walnut
        case .technical: .graphite
        case .cute:      .blossom
        case .chic:      .noir
        case .cool:      .glacier
        case .retro:     .sunset
        }
    }

    var face: FaceStyle {
        switch self {
        case .classic:   .ring
        case .technical: .digits
        case .cute:      .dots
        case .chic:      .hairline
        case .cool:      .bar
        case .retro:     .sunburst
        }
    }
}

// MARK: - Custom colours

/// The colours a person picks. Everything else in the palette is derived from
/// these, and derived so that text stays readable whatever they pick.
struct CustomColors: Codable, Equatable {
    var background: String
    var text: String
    var accent: String
    var highlight: String
    var highlight2: String
    var timerBackground: String
    var timerAccent: String

    /// Seeds a custom palette from whichever one the person was on, so the
    /// first change they make is the only change they see.
    init(from p: Palette) {
        background = RGB(p.paper).hex
        text = RGB(p.ink).hex
        accent = RGB(p.primary).hex
        highlight = RGB(p.secondary).hex
        highlight2 = RGB(p.tertiary).hex
        timerBackground = RGB(p.face).hex
        timerAccent = RGB(p.faceAccent).hex
    }

    static func decode(_ json: String) -> CustomColors? {
        try? JSONDecoder().decode(CustomColors.self, from: Data(json.utf8))
    }

    var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    var palette: Palette {
        let paper = RGB(hex: background) ?? RGB(Palette.walnut.paper)
        let ink = RGB(hex: text) ?? RGB(Palette.walnut.ink)
        let primary = RGB(hex: accent) ?? RGB(Palette.walnut.primary)
        let face = RGB(hex: timerBackground) ?? RGB(Palette.walnut.face)
        let faceInk = face.bestText(from: [paper, ink])

        return Palette(
            paper: paper.color,
            panel: paper.mixed(with: ink, by: 0.08).color,
            ink: ink.color,
            inkSoft: ink.mixed(with: paper, by: 0.38).color,
            rule: paper.mixed(with: ink, by: 0.16).color,
            primary: primary.color,
            onPrimary: primary.bestText(from: [paper, ink]).color,
            primaryText: primary.readable(on: paper).color,
            secondary: (RGB(hex: highlight) ?? primary).color,
            tertiary: (RGB(hex: highlight2) ?? primary).color,
            scheme: paper.luminance < 0.4 ? .dark : .light,
            face: face.color,
            faceInk: faceInk.color,
            faceSoft: faceInk.mixed(with: face, by: 0.42).color,
            faceTrack: face.mixed(with: faceInk, by: 0.14).color,
            faceAccent: (RGB(hex: timerAccent) ?? primary).color,
            faceAccent2: (RGB(hex: highlight) ?? primary).color
        )
    }
}

/// An sRGB colour with the arithmetic custom palettes need: hex in and out,
/// mixing, and WCAG contrast.
struct RGB: Equatable {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) {
        (self.r, self.g, self.b) = (r, g, b)
    }

    init(_ color: Color) {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: min(1, max(0, r)), g: min(1, max(0, g)), b: min(1, max(0, b)))
    }

    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let v = UInt32(digits, radix: 16) else { return nil }
        self.init(
            r: Double((v >> 16) & 0xFF) / 255,
            g: Double((v >> 8) & 0xFF) / 255,
            b: Double(v & 0xFF) / 255
        )
    }

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 1, g: 1, b: 1)

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    var color: Color { Color(red: r, green: g, blue: b) }

    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func contrast(with other: RGB) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func mixed(with other: RGB, by t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// The candidate that reads best on this colour, with black and white
    /// always in the running so there is never no answer.
    func bestText(from candidates: [RGB]) -> RGB {
        (candidates + [.black, .white]).max { contrast(with: $0) < contrast(with: $1) } ?? .black
    }

    /// This colour, darkened or lightened just enough to be small text on
    /// `ground` — the rule `primaryText` exists for.
    func readable(on ground: RGB, minimum: Double = 4.5) -> RGB {
        let toward = ground.bestText(from: [])
        for step in 0...10 {
            let candidate = mixed(with: toward, by: Double(step) / 10)
            if candidate.contrast(with: ground) >= minimum { return candidate }
        }
        return toward
    }
}

// MARK: - Resolution

/// Turns what's in defaults into what the views draw, with the refund rule
/// every Pro option follows: anything Pro falls back to the free choice.
enum Appearance {
    static let customTheme = "custom"

    static func palette(themeRaw: String, customJSON: String, isPro: Bool) -> Palette {
        guard isPro else { return ThemeID.walnut.palette }
        if themeRaw == customTheme, let custom = CustomColors.decode(customJSON) {
            return custom.palette
        }
        return (ThemeID(rawValue: themeRaw) ?? .walnut).palette
    }

    static func look(_ stored: Look, isPro: Bool) -> Look {
        isPro ? stored : .classic
    }
}

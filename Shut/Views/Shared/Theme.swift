import SwiftUI

/// Zawmbi Productions house palette: cream ground, green accent.
enum Theme {
    static let cream      = Color(red: 0.972, green: 0.960, blue: 0.925)
    static let creamDeep  = Color(red: 0.945, green: 0.929, blue: 0.882)
    static let ink        = Color(red: 0.110, green: 0.125, blue: 0.106)
    static let inkSoft    = Color(red: 0.365, green: 0.388, blue: 0.353)
    static let green      = Color(red: 0.176, green: 0.435, blue: 0.290)
    static let greenLight = Color(red: 0.490, green: 0.725, blue: 0.565)
    static let rule       = Color(red: 0.855, green: 0.839, blue: 0.788)

    /// The app commits to one visual world on purpose: it is meant to be read
    /// in a dark room on an outer display, and a light/dark swap would make the
    /// timer face inconsistent between poses.
    static let scheme: ColorScheme = .light
}

extension Font {
    /// The app's type scale.
    ///
    /// `Font.system(size:)` ignores Dynamic Type entirely, so every piece of
    /// real text goes through a text style instead. The fixed sizes this
    /// replaced mapped almost exactly onto the built-in styles — 11pt is
    /// `.caption2`, 15pt is `.subheadline`, 34pt is `.largeTitle` — so the
    /// design is unchanged at the default size and now grows with the setting.
    ///
    /// The big numerals on the timer, interrupt and result screens keep a fixed
    /// size on purpose: they are already far larger than any Dynamic Type step,
    /// and each one carries an accessibility label that reads the time aloud.
    static func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }

    /// The same scale in the system face, for body copy and controls.
    static func plain(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }
}

extension Text {
    /// Small uppercase label, used for every secondary line in the app.
    func labelStyle() -> some View {
        self.font(.rounded(.caption2, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}

extension View {
    func creamBackground() -> some View {
        background(Theme.cream.ignoresSafeArea())
    }
}

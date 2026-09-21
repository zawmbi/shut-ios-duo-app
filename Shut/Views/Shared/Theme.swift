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

extension Text {
    /// Small uppercase label, used for every secondary line in the app.
    func labelStyle() -> some View {
        self.font(.system(size: 11, weight: .semibold, design: .rounded))
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

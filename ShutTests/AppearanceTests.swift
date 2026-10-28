import SwiftUI
import Testing

@testable import Shut

/// Styles, palettes and custom colours: every built-in palette is readable,
/// custom colours can't produce unreadable text where the app derives it, and
/// everything beyond Classic is Pro.
struct AppearanceTests {

    @Test(arguments: ThemeID.allCases)
    func builtInPalettesAreReadable(_ theme: ThemeID) {
        let p = theme.palette
        #expect(RGB(p.ink).contrast(with: RGB(p.paper)) >= 4.5, "ink on paper")
        #expect(RGB(p.primaryText).contrast(with: RGB(p.paper)) >= 4.5, "primaryText on paper")
        // Bold labels on the primary block count as large text.
        #expect(RGB(p.onPrimary).contrast(with: RGB(p.primary)) >= 3, "onPrimary on primary")
        #expect(RGB(p.faceInk).contrast(with: RGB(p.face)) >= 4.5, "faceInk on face")
    }

    @Test(arguments: ThemeID.allCases)
    func builtInFacesAreDark(_ theme: ThemeID) {
        #expect(RGB(theme.palette.face).luminance < 0.05)
    }

    @Test func customPaletteKeepsDerivedTextReadable() {
        var colors = CustomColors(from: .walnut)
        // A pale accent on a pale ground, and a light timer background.
        colors.background = "#FFFFFF"
        colors.accent = "#FFE680"
        colors.timerBackground = "#F0F0F0"
        let p = colors.palette
        #expect(RGB(p.primaryText).contrast(with: RGB(p.paper)) >= 4.5)
        #expect(RGB(p.onPrimary).contrast(with: RGB(p.primary)) >= 4.5)
        #expect(RGB(p.faceInk).contrast(with: RGB(p.face)) >= 4.5)
    }

    @Test func customPaletteFollowsGroundForScheme() {
        var colors = CustomColors(from: .walnut)
        colors.background = "#101418"
        colors.text = "#F0F0F0"
        #expect(colors.palette.scheme == .dark)
        colors.background = "#FAFAFA"
        colors.text = "#111111"
        #expect(colors.palette.scheme == .light)
    }

    @Test func customColorsRoundTrip() {
        let colors = CustomColors(from: .sunset)
        #expect(CustomColors.decode(colors.encoded) == colors)
        #expect(colors.background == "#F5E6CC")
    }

    @Test func hexParsing() {
        #expect(RGB(hex: "#FF5A1F")?.hex == "#FF5A1F")
        #expect(RGB(hex: "2E6B66")?.hex == "#2E6B66")
        #expect(RGB(hex: "#FFF") == nil)
        #expect(RGB(hex: "nothex") == nil)
    }

    @Test func onlyClassicIsFree() {
        #expect(StyleID.allCases.filter { !$0.isPro } == [.classic])
        #expect(StyleID.classic.look == .classic)
        #expect(!StyleID.classic.theme.isPro)
        #expect(!StyleID.classic.face.isPro)
    }

    @Test func refundFallsBackToClassic() {
        let custom = CustomColors(from: .glacier).encoded
        let stored = StyleID.technical.look
        #expect(Appearance.look(stored, isPro: false) == .classic)
        #expect(Appearance.look(stored, isPro: true) == stored)
        #expect(Appearance.palette(themeRaw: "custom", customJSON: custom, isPro: false) == .walnut)
        #expect(Appearance.palette(themeRaw: "noir", customJSON: "", isPro: true) == .noir)
        // A custom selection with nothing saved behind it falls back too.
        #expect(Appearance.palette(themeRaw: "custom", customJSON: "", isPro: true) == .walnut)
    }
}

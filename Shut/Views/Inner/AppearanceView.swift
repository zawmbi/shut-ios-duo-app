import SwiftUI

/// Appearance, edited the way the Lock Screen is: a live preview on top, a
/// row of styles to start from, then one component at a time, each option
/// drawn as itself.
///
/// Every change is written straight to defaults, so the preview above — and
/// the rest of the app — follows it immediately. Free sees every option and
/// can pick the Classic ones; the rest are marked Pro and do nothing. The
/// paywall lives in exactly two places, and this isn't one of them.
struct AppearanceView: View {
    @Environment(Entitlements.self) private var pro
    @Environment(\.palette) private var palette
    @Environment(\.look) private var look

    @AppStorage(PrefKey.theme) private var themeRaw: String = ThemeID.walnut.rawValue
    @AppStorage(PrefKey.customColors) private var customJSON: String = ""
    @AppStorage(PrefKey.faceStyle) private var faceRaw: String = FaceStyle.ring.rawValue
    @AppStorage(PrefKey.textFace) private var textFace: TextFace = .sans
    @AppStorage(PrefKey.numeralFace) private var numeralFace: NumeralFace = .rounded
    @AppStorage(PrefKey.numeralWeight) private var numeralWeight: NumeralWeight = .bold
    @AppStorage(PrefKey.corners) private var corners: Corners = .soft

    @State private var component: Component = .initial

    enum Component: String, CaseIterable, Identifiable {
        case clock, timer, colours, background, text, shape
        var id: String { rawValue }
        var display: String { rawValue.capitalized }

        /// Clock, or for a staged screenshot whichever tab `-appearance.tab` names.
        static var initial: Component {
            #if DEBUG
            if let raw = UserDefaults.standard.string(forKey: "appearance.tab"), let tab = Component(rawValue: raw) {
                return tab
            }
            #endif
            return .clock
        }
    }

    private var face: FaceStyle {
        let chosen = FaceStyle(rawValue: faceRaw) ?? .ring
        return (chosen.isPro && !pro.isPro) ? .ring : chosen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                preview
                styles
                VStack(alignment: .leading, spacing: 16) {
                    componentBar
                    options
                }
                if !pro.isPro {
                    Text("Classic is free. Every other style, colour, face, font and corner comes with Shut Pro, from Settings.")
                        .font(.plain(.footnote))
                        .foregroundStyle(palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .readableWidth()
        }
        .paperBackground()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Preview

    private var preview: some View {
        HStack(alignment: .top, spacing: 14) {
            device("Timer") { FaceCanvas(style: face) }
            device("Home") { HomeCanvas() }
        }
        .frame(maxWidth: .infinity)
    }

    private func device<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Miniature(scale: 0.48, content: content)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(palette.rule, lineWidth: 1)
                }
            Text(title).labelStyle()
        }
    }

    // MARK: - Styles

    private var currentStyle: StyleID? {
        let stored = Look(text: textFace, numerals: numeralFace, weight: numeralWeight, corners: corners)
        return StyleID.allCases.first {
            $0.look == stored && $0.theme.rawValue == themeRaw && $0.face.rawValue == faceRaw
        }
    }

    private var styles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style").labelStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StyleID.allCases) { style in
                        OptionTile(
                            title: style.display,
                            selected: currentStyle == style,
                            locked: style.isPro && !pro.isPro
                        ) {
                            apply(style)
                        } content: {
                            // Face and home together: the face alone hides the
                            // paper, the type and the corners, which is most
                            // of what tells two styles apart.
                            HStack(spacing: 0) {
                                Miniature(scale: 0.24) { FaceCanvas(style: style.face) }
                                Miniature(scale: 0.24) { HomeCanvas() }
                            }
                            .wearing(style.theme.palette, style.look)
                        }
                        .frame(width: 154)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func apply(_ style: StyleID) {
        textFace = style.look.text
        numeralFace = style.look.numerals
        numeralWeight = style.look.weight
        corners = style.look.corners
        themeRaw = style.theme.rawValue
        faceRaw = style.face.rawValue
    }

    // MARK: - Components

    private var componentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Component.allCases) { c in
                    Button { component = c } label: {
                        Text(c.display)
                            .font(.plain(.subheadline, .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(component == c ? palette.primary : palette.panel)
                            .foregroundStyle(component == c ? palette.onPrimary : palette.ink)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(component == c ? [.isSelected] : [])
                }
            }
        }
    }

    @ViewBuilder private var options: some View {
        switch component {
        case .clock:      clockOptions
        case .timer:      timerOptions
        case .colours:    colourOptions
        case .background: backgroundOptions
        case .text:       textOptions
        case .shape:      shapeOptions
        }
    }

    private var clockOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            grid(NumeralFace.allCases) { f in
                OptionTile(title: f.display, selected: numeralFace == f, locked: f != .rounded && !pro.isPro) {
                    numeralFace = f
                } content: {
                    swatch(palette.face) {
                        Text("18:42")
                            .font(.system(size: 26, weight: numeralWeight.weight, design: f.design))
                            .foregroundStyle(palette.faceInk)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    }
                }
            }
            Text("Weight").labelStyle()
            grid(NumeralWeight.allCases) { w in
                OptionTile(title: w.display, selected: numeralWeight == w, locked: w != .bold && !pro.isPro) {
                    numeralWeight = w
                } content: {
                    swatch(palette.face) {
                        Text("42")
                            .font(.system(size: 30, weight: w.weight, design: numeralFace.design))
                            .foregroundStyle(palette.faceInk)
                    }
                }
            }
        }
    }

    private var timerOptions: some View {
        grid(FaceStyle.allCases, minimum: 140) { f in
            OptionTile(title: f.display, selected: face == f, locked: f.isPro && !pro.isPro) {
                faceRaw = f.rawValue
            } content: {
                Miniature(scale: 0.4) { FaceCanvas(style: f) }
                    .frame(maxWidth: .infinity)
                    .background(palette.face)
            }
        }
    }

    private var colourOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 14) {
                ForEach(ThemeID.allCases) { t in
                    OptionTile(title: t.display, selected: themeRaw == t.rawValue, locked: t.isPro && !pro.isPro) {
                        themeRaw = t.rawValue
                    } content: {
                        themeSwatch(t.palette)
                    }
                }
                // Back to the last custom palette, or a new one seeded from
                // whatever is showing now.
                OptionTile(title: "Custom", selected: themeRaw == Appearance.customTheme, locked: !pro.isPro) {
                    if CustomColors.decode(customJSON) == nil { customJSON = custom.encoded }
                    themeRaw = Appearance.customTheme
                } content: {
                    themeSwatch(custom.palette)
                }
            }

            Text("Your colours").labelStyle()
            VStack(spacing: 0) {
                picker("Text", \.text)
                picker("Accent", \.accent)
                picker("Highlight", \.highlight)
                picker("Second highlight", \.highlight2)
                picker("Timer accent", \.timerAccent)
            }
            .background(palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous))
            .disabled(!pro.isPro)
        }
    }

    private var backgroundOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home and history").labelStyle()
            swatchRow(ThemeID.allCases.map(\.palette.paper), \.background)
            Text("Timer").labelStyle()
            swatchRow(ThemeID.allCases.map(\.palette.face), \.timerBackground)
            VStack(spacing: 0) {
                picker("Background", \.background)
                picker("Timer background", \.timerBackground)
            }
            .background(palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous))
            .disabled(!pro.isPro)
        }
    }

    private var textOptions: some View {
        grid(TextFace.allCases) { f in
            OptionTile(title: f.display, selected: textFace == f, locked: f != .sans && !pro.isPro) {
                textFace = f
            } content: {
                swatch(palette.panel) {
                    VStack(spacing: 4) {
                        Text("Aa")
                            .font(.system(size: 26, weight: .heavy, design: f.design))
                            .foregroundStyle(palette.ink)
                        Text("Block")
                            .font(.system(size: 9, weight: .bold, design: f.design))
                            .tracking(f.labelTracking)
                            .textCase(f.labelUppercase ? .uppercase : nil)
                            .foregroundStyle(palette.inkSoft)
                    }
                }
            }
        }
    }

    private var shapeOptions: some View {
        grid(Corners.allCases) { c in
            OptionTile(title: c.display, selected: corners == c, locked: c != .soft && !pro.isPro) {
                corners = c
            } content: {
                swatch(palette.panel) {
                    RoundedRectangle(cornerRadius: c.radius, style: .continuous)
                        .fill(palette.primary)
                        .frame(width: 64, height: 40)
                }
            }
        }
    }

    // MARK: - Custom colours

    /// The custom palette if there is one, otherwise the current palette as a
    /// starting point — so the first edit changes one colour, not all of them.
    private var custom: CustomColors {
        (themeRaw == Appearance.customTheme ? CustomColors.decode(customJSON) : nil)
            ?? CustomColors(from: palette)
    }

    private func set(_ key: WritableKeyPath<CustomColors, String>, _ rgb: RGB) {
        var colors = custom
        colors[keyPath: key] = rgb.hex
        customJSON = colors.encoded
        themeRaw = Appearance.customTheme
    }

    private func picker(_ title: String, _ key: WritableKeyPath<CustomColors, String>) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { (RGB(hex: custom[keyPath: key]) ?? .black).color },
                set: { set(key, RGB($0)) }
            ),
            supportsOpacity: false
        )
        .font(.plain(.body))
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func swatchRow(_ colors: [Color], _ key: WritableKeyPath<CustomColors, String>) -> some View {
        let current = custom[keyPath: key]
        // Several themes share a ground; one dot per colour.
        let unique = colors.map(RGB.init).reduce(into: [RGB]()) { if !$0.contains($1) { $0.append($1) } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(unique, id: \.hex) { rgb in
                    Button { set(key, rgb) } label: {
                        Circle()
                            .fill(rgb.color)
                            .frame(width: 40, height: 40)
                            .overlay { Circle().strokeBorder(palette.rule, lineWidth: 1) }
                            .overlay {
                                if rgb.hex == current {
                                    Circle().strokeBorder(palette.ink, lineWidth: 2.5).padding(-4)
                                }
                            }
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!pro.isPro)
                    .accessibilityLabel("Colour \(rgb.hex)")
                    .accessibilityAddTraits(rgb.hex == current ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Pieces

    private func grid<Item: Identifiable, Tile: View>(
        _ items: [Item],
        minimum: CGFloat = 72,
        @ViewBuilder tile: @escaping (Item) -> Tile
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 12)], spacing: 14) {
            ForEach(items) { tile($0) }
        }
    }

    private func swatch<Content: View>(_ ground: Color, @ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            ground
            content()
        }
        .frame(height: 72)
    }

    private func themeSwatch(_ p: Palette) -> some View {
        ZStack {
            p.paper
            HStack(spacing: -6) {
                ForEach(Array([p.primary, p.secondary, p.tertiary].enumerated()), id: \.offset) { _, c in
                    Circle().fill(c).frame(width: 20, height: 20)
                        .overlay(Circle().stroke(p.paper, lineWidth: 2))
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(p.face)
                    .frame(width: 14, height: 20)
                    .overlay(Circle().fill(p.faceAccent).frame(width: 6, height: 6))
                    .padding(.leading, 10)
            }
        }
        .frame(height: 72)
    }
}

// MARK: - Canvases

/// The real view drawn at full size, then scaled down — a preview is the
/// thing itself, not a sketch of it.
private struct Miniature<Content: View>: View {
    static var canvas: CGSize { CGSize(width: 320, height: 440) }

    let scale: CGFloat
    let content: Content

    init(scale: CGFloat, @ViewBuilder content: () -> Content) {
        self.scale = scale
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: Self.canvas.width, height: Self.canvas.height)
            .scaleEffect(scale)
            .frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The timer face at 18:42 of 45 minutes.
private struct FaceCanvas: View {
    let style: FaceStyle
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.face
            FaceArt(style: style, progress: 0.58, indeterminate: false, time: "18:42", caption: "Left")
        }
    }
}

/// The home screen, cut down to what shows the type, colour and shape.
private struct HomeCanvas: View {
    @Environment(HingeMonitor.self) private var hinge
    @Environment(\.palette) private var palette
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                FoldMark(size: 24)
                Text("Shut")
                    .font(.plain(.title2, .black))
                    .tracking(6)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.ink)
            }
            Spacer(minLength: 0)
            Text("Block length").labelStyle()
            HStack(spacing: 8) {
                tile("25m", selected: true)
                tile("45m", selected: false)
                tile("1h", selected: false)
            }
            Spacer(minLength: 0)
            Text(hinge.trigger.verb)
                .font(.plain(.title2, .heavy))
                .foregroundStyle(palette.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                .padding(.leading, 18)
                .background(alignment: .trailing) {
                    ZStack(alignment: .trailing) {
                        palette.primary
                        Circle().fill(palette.secondary).frame(width: 90, height: 90).offset(x: 34)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous))
            Spacer(minLength: 0)
            Rectangle().fill(palette.ink).frame(height: 2)
            HStack(spacing: 24) {
                stat("Today", "1h 25m")
                stat("Streak", "17 days")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.paper)
    }

    private func tile(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.plain(.body, .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? palette.primary : palette.panel)
            .foregroundStyle(selected ? palette.onPrimary : palette.ink)
            .clipShape(RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).labelStyle()
            Text(value)
                .font(.plain(.title3, .heavy))
                .foregroundStyle(palette.ink)
        }
    }
}

/// One option: the option drawn as itself, its name beneath.
private struct OptionTile<Content: View>: View {
    let title: String
    let selected: Bool
    let locked: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                content()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: look.corners.radius, style: .continuous)
                            .strokeBorder(selected ? palette.ink : palette.rule, lineWidth: selected ? 2.5 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.paper)
                                .padding(5)
                                .background(palette.ink, in: Circle())
                                .padding(5)
                        }
                    }
                Text(title)
                    .font(.plain(.caption, .semibold))
                    .foregroundStyle(locked ? palette.inkSoft : palette.ink)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(locked ? "Requires Shut Pro" : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private extension View {
    /// Dresses a preview in a palette and look other than the current ones.
    func wearing(_ palette: Palette, _ look: Look) -> some View {
        environment(\.palette, palette)
            .environment(\.look, look)
            .fontDesign(look.text.design)
    }
}

#Preview("Appearance") {
    NavigationStack {
        AppearanceView()
    }
    .environment(Entitlements())
    .environment(HingeMonitor())
}

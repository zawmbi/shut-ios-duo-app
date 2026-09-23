import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Environment(HingeMonitor.self) private var hinge
    @Environment(\.palette) private var palette

    @AppStorage(PrefKey.graceSeconds) private var grace: Int = Prefs.defaultGraceSeconds
    @AppStorage(PrefKey.soundOnFinish) private var sound: Bool = true
    @AppStorage(PrefKey.faceStyle) private var faceRaw: String = FaceStyle.ring.rawValue
    @AppStorage(PrefKey.theme) private var themeRaw: String = ThemeID.walnut.rawValue
    @AppStorage(PrefKey.encouragement) private var encourage = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    if pro.isPro {
                        Stepper(
                            "Grace period: \(grace)s",
                            value: $grace,
                            in: Prefs.graceRange,
                            step: 1
                        )
                    } else {
                        HStack {
                            Text("Grace period")
                            Spacer()
                            Text("\(Prefs.defaultGraceSeconds)s").foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Sound when a block ends", isOn: $sound)
                }

                Section {
                    Toggle("Encouragement", isOn: $encourage)
                } footer: {
                    Text("A short note on the timer face, the grace screen and the result. Off, the app just states the facts.")
                }

                Section {
                    ForEach(ThemeID.allCases) { theme in
                        themeRow(theme)
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text(pro.isPro
                         ? "Colours for both displays. The folded face is always dark."
                         : "Walnut is free. Avocado, Atomic and Dusk come with Pro.")
                }

                Section {
                    if pro.isPro {
                        Picker("Face", selection: $faceRaw) {
                            ForEach(FaceStyle.allCases) { style in
                                Text(style.display).tag(style.rawValue)
                            }
                        }
                    } else {
                        HStack {
                            Text("Face")
                            Spacer()
                            Text(FaceStyle.ring.display).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Timer face")
                } footer: {
                    Text(pro.isPro
                         ? "What the outer display shows while the phone is shut."
                         : "The ring is free. Sunburst, digits and bar come with Pro.")
                }

                if !pro.isPro {
                    Section {
                        Button("Shut Pro — \(pro.priceText)") { showPaywall = true }
                        Button("Restore purchase") { Task { await pro.restore() } }
                    }
                }

                Section("Privacy") {
                    Text("Shut collects nothing and sends nothing anywhere. Your blocks are stored on this phone only.")
                        .font(.plain(.footnote))
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Device", value: hinge.isFoldable ? "iPhone Duo" : "iPhone")
                    LabeledContent("Trigger", value: hinge.trigger == .fold ? "Fold" : "Lock")
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Zawmbi Productions")
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task { await pro.load() }
        }
    }

    private func themeRow(_ theme: ThemeID) -> some View {
        let locked = theme.isPro && !pro.isPro
        let selected = (ThemeID(rawValue: themeRaw) ?? .walnut) == theme && !locked
        let p = theme.palette
        return Button {
            themeRaw = theme.rawValue
        } label: {
            HStack(spacing: 14) {
                // The theme's primary, secondary and tertiary colours, with
                // its folded face beside them.
                HStack(spacing: -6) {
                    ForEach(Array([p.primary, p.secondary, p.tertiary].enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(p.paper, lineWidth: 2))
                    }
                }
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(p.face)
                    .frame(width: 16, height: 22)
                    .overlay(Circle().fill(p.faceAccent).frame(width: 7, height: 7))
                Text(theme.display)
                    .foregroundStyle(palette.ink)
                Spacer()
                if locked {
                    Text("Pro").font(.plain(.caption, .bold)).foregroundStyle(palette.inkSoft)
                } else if selected {
                    Image(systemName: "checkmark").font(.plain(.body, .bold)).foregroundStyle(palette.primaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.display)
        .accessibilityValue(locked ? "Requires Shut Pro" : "")
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

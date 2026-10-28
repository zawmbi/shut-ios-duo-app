import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Environment(HingeMonitor.self) private var hinge
    @Environment(\.palette) private var palette

    @AppStorage(PrefKey.graceSeconds) private var grace: Int = Prefs.defaultGraceSeconds
    @AppStorage(PrefKey.soundOnFinish) private var sound: Bool = true
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
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        HStack(spacing: 14) {
                            HStack(spacing: -6) {
                                ForEach(Array([palette.primary, palette.secondary, palette.tertiary].enumerated()), id: \.offset) { _, c in
                                    Circle().fill(c).frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(palette.paper, lineWidth: 2))
                                }
                            }
                            .accessibilityHidden(true)
                            Text("Appearance").foregroundStyle(palette.ink)
                        }
                    }
                } footer: {
                    Text(pro.isPro
                         ? "Style, colours, clock, timer face, text and corners."
                         : "Classic is free. Five more styles, every timer face, and your own colours and type come with Pro.")
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
}

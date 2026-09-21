import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Environment(HingeMonitor.self) private var hinge

    @AppStorage(PrefKey.graceSeconds) private var grace: Int = Prefs.defaultGraceSeconds
    @AppStorage(PrefKey.soundOnFinish) private var sound: Bool = true
    @AppStorage(PrefKey.faceStyle) private var faceRaw: String = FaceStyle.ring.rawValue
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
                         : "The ring is free. Digits and bar come with Pro.")
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

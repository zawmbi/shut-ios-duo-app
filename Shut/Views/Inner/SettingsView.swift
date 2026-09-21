import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Environment(HingeMonitor.self) private var hinge

    @AppStorage(PrefKey.graceSeconds) private var grace: Int = 10
    @AppStorage(PrefKey.soundOnFinish) private var sound: Bool = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    if pro.isPro {
                        Stepper("Grace period: \(grace)s", value: $grace, in: 3...60, step: 1)
                    } else {
                        HStack {
                            Text("Grace period")
                            Spacer()
                            Text("10s").foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Sound when a block ends", isOn: $sound)
                }

                if !pro.isPro {
                    Section {
                        Button("Shut Pro — \(pro.priceText)") { showPaywall = true }
                        Button("Restore purchase") { Task { await pro.restore() } }
                    }
                }

                Section("Privacy") {
                    Text("Shut collects nothing and sends nothing anywhere. Your blocks are stored on this phone only.")
                        .font(.system(size: 13))
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

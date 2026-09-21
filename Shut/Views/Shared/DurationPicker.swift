import SwiftUI

struct DurationPicker: View {
    @Binding var seconds: Int

    @Environment(Entitlements.self) private var pro
    @AppStorage(PrefKey.customTarget) private var customTarget: Int = 0

    @State private var showCustom = false
    @State private var showPaywall = false

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Presets.all, id: \.self) { value in
                cell(Presets.label(value), selected: seconds == value) {
                    seconds = value
                }
                .accessibilityLabel(value == 0 ? "Open ended block" : "\(value / 60) minute block")
                .accessibilityAddTraits(seconds == value ? [.isSelected] : [])
            }

            cell(customLabel, selected: isCustomSelected) {
                if pro.isPro {
                    showCustom = true
                } else {
                    showPaywall = true
                }
            }
            .accessibilityLabel(customAccessibilityLabel)
            .accessibilityAddTraits(isCustomSelected ? [.isSelected] : [])
        }
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(seconds: $seconds, customTarget: $customTarget)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func cell(
        _ label: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.rounded(.body, .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Theme.green : Theme.creamDeep)
                .foregroundStyle(selected ? Theme.cream : Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - The custom cell

    /// A custom length that happens to equal a preset highlights the preset
    /// instead. Two lit cells for one duration would be a lie about state.
    private var isCustomSelected: Bool {
        customTarget > 0 && seconds == customTarget && !Presets.all.contains(customTarget)
    }

    private var customLabel: String {
        customTarget > 0 && !Presets.all.contains(customTarget)
            ? Presets.label(customTarget)
            : "Custom"
    }

    private var customAccessibilityLabel: String {
        guard pro.isPro else { return "Custom length, requires Shut Pro" }
        return customTarget > 0
            ? "Custom length, \(customTarget / 60) minutes"
            : "Set a custom length"
    }
}

private struct CustomDurationSheet: View {
    @Binding var seconds: Int
    @Binding var customTarget: Int

    @Environment(\.dismiss) private var dismiss

    @State private var hours = 0
    @State private var minutes = 30

    private var total: Int { hours * 3600 + minutes * 60 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 0) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0..<9, id: \.self) { value in
                            Text("\(value) h").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { value in
                            Text("\(value) m").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(maxHeight: 180)

                Text(total == 0 ? "At least one minute." : Presets.label(total))
                    .font(.rounded(.body, .semibold))
                    .foregroundStyle(total == 0 ? Theme.inkSoft : Theme.ink)
                    .monospacedDigit()

                Spacer()
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
            .creamBackground()
            .navigationTitle("Custom length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        customTarget = total
                        seconds = total
                        dismiss()
                    }
                    .disabled(total == 0)
                }
            }
            .onAppear {
                let start = customTarget > 0 ? customTarget : seconds
                guard start > 0 else { return }
                hours = min(8, start / 3600)
                minutes = (start % 3600) / 60
            }
        }
    }
}

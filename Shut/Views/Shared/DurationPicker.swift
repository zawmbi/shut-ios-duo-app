import SwiftUI

struct DurationPicker: View {
    @Binding var seconds: Int

    @Environment(Entitlements.self) private var pro
    @Environment(\.palette) private var palette
    @AppStorage(PrefKey.customTarget) private var customTarget: Int = 0

    @State private var showCustom = false

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Presets.all, id: \.self) { value in
                cell(Presets.label(value), selected: seconds == value) {
                    seconds = value
                }
                .accessibilityLabel(value == 0 ? "No limit" : "\(value / 60) minute block")
                .accessibilityAddTraits(seconds == value ? [.isSelected] : [])
            }

            // Free sees the Custom tile locked rather than a paywall: the paywall
            // lives in exactly two places, History and Settings.
            cell(customLabel, selected: isCustomSelected, locked: !pro.isPro) {
                showCustom = true
            }
            .disabled(!pro.isPro)
            .accessibilityLabel(customAccessibilityLabel)
            .accessibilityAddTraits(isCustomSelected ? [.isSelected] : [])
        }
        .sheet(isPresented: $showCustom) {
            CustomDurationSheet(seconds: $seconds, customTarget: $customTarget)
        }
    }

    private func cell(
        _ label: String,
        selected: Bool,
        locked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill").font(.plain(.caption2, .bold))
                }
                Text(label)
            }
                .font(.plain(.body, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selected ? palette.primary : palette.panel)
                .foregroundStyle(selected ? palette.onPrimary : (locked ? palette.inkSoft : palette.ink))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        guard pro.isPro else { return "Custom length, requires Shut Pro. Available from Settings." }
        return customTarget > 0
            ? "Custom length, \(customTarget / 60) minutes"
            : "Set a custom length"
    }
}

private struct CustomDurationSheet: View {
    @Binding var seconds: Int
    @Binding var customTarget: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

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
                    .foregroundStyle(total == 0 ? palette.inkSoft : palette.ink)
                    .monospacedDigit()

                Spacer()
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
            .paperBackground()
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

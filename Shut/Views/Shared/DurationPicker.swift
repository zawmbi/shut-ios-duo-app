import SwiftUI

struct DurationPicker: View {
    @Binding var seconds: Int

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Presets.all, id: \.self) { value in
                Button {
                    seconds = value
                } label: {
                    Text(Presets.label(value))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(seconds == value ? Theme.green : Theme.creamDeep)
                        .foregroundStyle(seconds == value ? Theme.cream : Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == 0 ? "Open ended block" : "\(value / 60) minute block")
                .accessibilityAddTraits(seconds == value ? [.isSelected] : [])
            }
        }
    }
}

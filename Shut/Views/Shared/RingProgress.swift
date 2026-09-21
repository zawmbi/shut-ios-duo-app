import SwiftUI

struct RingProgress: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var indeterminate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.rule, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: indeterminate ? 1 : max(0.001, min(1, progress)))
                .stroke(
                    indeterminate ? Theme.rule : Theme.green,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: progress)
        }
        .accessibilityHidden(true)
    }
}

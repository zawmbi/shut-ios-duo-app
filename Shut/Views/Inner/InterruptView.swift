import SwiftUI

/// Shown on the inner display when the user releases mid-block. The grace
/// period is load-bearing: a hard fail on any unfold earns one-star reviews
/// from people who opened the phone to check the time.
struct InterruptView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(SessionClock.self) private var clock

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(hinge.trigger.breakVerb).labelStyle()

            Text(Stats.clock(engine.graceRemaining))
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.top, 4)
                .accessibilityLabel(
                    "\(Stats.spoken(engine.graceRemaining)) to \(hinge.trigger == .fold ? "fold" : "lock") it again"
                )
                .accessibilityAddTraits(.updatesFrequently)

            Text(remainingLine)
                .accessibilityLabel(spokenRemainingLine)
                .font(.plain(.callout))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 10) {
                Text(hinge.trigger == .fold ? "Fold it again to carry on." : "Lock it again to carry on.")
                    .font(.plain(.subheadline, .medium))
                    .foregroundStyle(Theme.green)

                Button("Break it") {
                    engine.breakNow()
                }
                .font(.rounded(.subheadline, .semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.vertical, 12)
                .padding(.horizontal, 28)
                .background(Theme.creamDeep)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .creamBackground()
        .onChange(of: clock.now) { _, _ in engine.tick() }
    }

    private var remainingLine: String {
        guard let remaining = engine.remaining else {
            return "\(Stats.format(engine.elapsed)) in. Nothing is lost yet."
        }
        return "\(Stats.format(remaining)) left. Nothing is lost yet."
    }

    private var spokenRemainingLine: String {
        guard let remaining = engine.remaining else {
            return "\(Stats.spoken(engine.elapsed)) in. Nothing is lost yet."
        }
        return "\(Stats.spoken(remaining)) left. Nothing is lost yet."
    }
}

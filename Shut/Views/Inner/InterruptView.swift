import SwiftUI

/// Shown on the inner display when the user releases mid-block. The grace
/// period is load-bearing: a hard fail on any unfold earns one-star reviews
/// from people who opened the phone to check the time.
struct InterruptView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(SessionClock.self) private var clock
    @Environment(\.palette) private var palette
    @AppStorage(PrefKey.encouragement) private var encourage = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(hinge.trigger.breakVerb).labelStyle()

            ZStack {
                // Grace drains as a ring of ticks, one per second of the
                // allowance, so the countdown reads at a glance.
                GraceTicks(
                    total: max(1, engine.graceSeconds),
                    remaining: engine.graceRemaining,
                    lit: palette.tertiary,
                    unlit: palette.rule
                )
                .frame(width: 240, height: 240)

                Text(Stats.clock(engine.graceRemaining))
                    .font(.numerals(64, .heavy))
                    .foregroundStyle(palette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.top, 16)
                .accessibilityLabel(
                    "\(Stats.spoken(engine.graceRemaining)) to \(hinge.trigger == .fold ? "fold" : "lock") it again"
                )
                .accessibilityAddTraits(.updatesFrequently)

            Text(remainingLine)
                .accessibilityLabel(spokenRemainingLine)
                .font(.plain(.callout))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 32)

            if encourage {
                Text(Encouragement.line(for: .grace(hinge.trigger), seed: engine.startedAt))
                    .font(.plain(.callout, .semibold))
                    .foregroundStyle(palette.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 10) {
                Text(hinge.trigger == .fold ? "Fold it again to carry on." : "Lock it again to carry on.")
                    .font(.plain(.subheadline, .bold))
                    .foregroundStyle(palette.primaryText)

                // An open-ended block isn't broken by stopping it — it ends kept.
                Button(engine.targetSeconds == 0 ? "End it" : "Break it") {
                    engine.breakNow()
                }
                .font(.plain(.subheadline, .bold))
                .tracking(1)
                .foregroundStyle(palette.ink)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(palette.ink, lineWidth: 2)
                )
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .onChange(of: clock.now) { _, _ in engine.tick() }
    }

    private var remainingLine: String {
        guard let remaining = engine.remaining else {
            return "\(Stats.format(engine.elapsed)) in. Leave it open and the block ends there."
        }
        return "\(Stats.format(remaining)) left. Nothing is lost yet."
    }

    private var spokenRemainingLine: String {
        guard let remaining = engine.remaining else {
            return "\(Stats.spoken(engine.elapsed)) in. Leave it open and the block ends there."
        }
        return "\(Stats.spoken(remaining)) left. Nothing is lost yet."
    }
}

private struct GraceTicks: View {
    let total: Int
    let remaining: TimeInterval
    let lit: Color
    let unlit: Color

    var body: some View {
        let count = min(total, 60)
        let on = Int((remaining / Double(total) * Double(count)).rounded(.up))
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i < on ? lit : unlit)
                    .frame(width: 4, height: 18)
                    .offset(y: -111)
                    .rotationEffect(.degrees(Double(i) / Double(count) * 360))
            }
        }
        .accessibilityHidden(true)
    }
}

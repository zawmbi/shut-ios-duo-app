import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(Entitlements.self) private var pro
    @Environment(\.palette) private var palette
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    @AppStorage(PrefKey.lastTarget) private var lastTarget: Int = 25 * 60
    @State private var showHistory = false
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 14) {
                Text("Block length").labelStyle()
                DurationPicker(seconds: $lastTarget)
            }

            Spacer(minLength: 28)

            instruction

            Spacer(minLength: 20)

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .paperBackground()
        .onAppear {
            // A custom length left over from a refunded Pro falls back to the
            // default, the same rule themes and faces follow.
            if !pro.isPro && !Presets.all.contains(lastTarget) { lastTarget = 25 * 60 }
            engine.arm(target: lastTarget)
        }
        .onChange(of: lastTarget) { _, new in engine.arm(target: new) }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            FoldMark()
            Text("Shut")
                .font(.plain(.title2, .black))
                .tracking(6)
                .textCase(.uppercase)
                .foregroundStyle(palette.ink)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.plain(.body, .semibold))
                    .foregroundStyle(palette.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
    }

    /// A flat block of the theme's primary colour with two shapes set into its
    /// corner — the one bold composition on the screen.
    private var instruction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(hinge.trigger.verb)
                .font(.plain(.title, .heavy))
                .foregroundStyle(palette.onPrimary)
            Text(subtitle)
                .font(.plain(.subheadline, .medium))
                .foregroundStyle(palette.onPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .padding(.leading, 22)
        .padding(.trailing, 88)
        .background(alignment: .bottomTrailing) {
            ZStack(alignment: .bottomTrailing) {
                palette.primary
                Circle()
                    .fill(palette.secondary)
                    .frame(width: 120, height: 120)
                    .offset(x: 44, y: -30)
                HalfDisc()
                    .fill(palette.tertiary)
                    .frame(width: 84, height: 42)
                    .offset(x: -18, y: 0)
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var subtitle: String {
        let grace = "\(Prefs.graceSeconds) seconds"
        switch hinge.trigger {
        case .fold:
            return lastTarget == 0
                ? "The timer runs on the outer display. Open the phone to stop it."
                : "The timer runs on the outer display. Open it before \(Presets.label(lastTarget)) is up and you have \(grace) to shut it again, or the block breaks."
        case .lock:
            return lastTarget == 0
                ? "Lock the screen to start. Unlock to stop."
                : "Lock the screen to start. Unlock or leave the app before \(Presets.label(lastTarget)) is up and you have \(grace) to lock it again, or the block breaks."
        }
    }

    private var streak: Int {
        Stats.streak(sessions, forgiveness: pro.isPro ? .weekly : .firstMiss)
    }

    private var todayText: String {
        let today = Stats.todayTotal(sessions)
        return today > 0 ? Stats.format(today) : "0 min"
    }

    private var footer: some View {
        Button { showHistory = true } label: {
            VStack(spacing: 14) {
                Rectangle().fill(palette.ink).frame(height: 2)
                HStack(spacing: 24) {
                    stat("Today", todayText)
                    Rectangle().fill(palette.rule).frame(width: 1, height: 32)
                    stat("Streak", "\(streak) day\(streak == 1 ? "" : "s")")
                    Spacer()
                    HStack(spacing: 6) {
                        Text("History")
                            .font(.plain(.subheadline, .bold))
                        Image(systemName: "arrow.right")
                            .font(.plain(.subheadline, .bold))
                    }
                    .foregroundStyle(palette.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The button's own label would otherwise replace the two figures
        // inside it, so VoiceOver would announce "History" and nothing else.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("History")
        .accessibilityValue(spokenStats)
    }

    private var spokenStats: String {
        let today = Stats.todayTotal(sessions)
        let todayPart = today > 0 ? "today \(Stats.spoken(today))" : "nothing today"
        return "\(todayPart), streak \(streak) day\(streak == 1 ? "" : "s")"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).labelStyle()
            Text(value)
                .font(.plain(.title2, .heavy))
                .foregroundStyle(palette.ink)
                .monospacedDigit()
        }
    }
}

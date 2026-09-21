import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(HingeMonitor.self) private var hinge
    @Environment(Entitlements.self) private var pro
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
        .creamBackground()
        .onAppear { engine.arm(target: lastTarget) }
        .onChange(of: lastTarget) { _, new in engine.arm(target: new) }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Shut")
                .font(.rounded(.largeTitle, .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.plain(.body, .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hinge.trigger.verb)
                .font(.rounded(.title, .bold))
                .foregroundStyle(Theme.green)
            Text(subtitle)
                .font(.plain(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.creamDeep)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var subtitle: String {
        switch hinge.trigger {
        case .fold:
            lastTarget == 0
                ? "The timer runs on the outer display. Open the phone to stop it."
                : "The timer runs on the outer display. Open it before \(Presets.label(lastTarget)) is up and the block breaks."
        case .lock:
            lastTarget == 0
                ? "Lock the screen to start. Unlock to stop."
                : "Lock the screen to start. Unlock before \(Presets.label(lastTarget)) is up and the block breaks."
        }
    }

    private var footer: some View {
        Button { showHistory = true } label: {
            HStack(spacing: 20) {
                stat("Today", Stats.format(Stats.todayTotal(sessions)))
                Divider().frame(height: 28).overlay(Theme.rule)
                stat("Streak", "\(Stats.streak(sessions)) d")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.plain(.footnote, .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("History")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).labelStyle()
            Text(value)
                .font(.rounded(.title3, .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
    }
}

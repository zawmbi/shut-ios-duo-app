import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    private var today: [Session] {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var visible: [Session] { pro.isPro ? sessions : today }

    var body: some View {
        NavigationStack {
            Group {
                if visible.isEmpty && !pro.isPro {
                    empty
                } else {
                    List {
                        if pro.isPro {
                            Section("Totals") {
                                summary
                            }
                        }

                        if visible.isEmpty {
                            Section {
                                empty.listRowBackground(Theme.creamDeep.opacity(0.5))
                            }
                        } else {
                            Section {
                                ForEach(visible) { session in
                                    row(session)
                                }
                            }
                        }

                        if !pro.isPro {
                            Section {
                                PaywallRow()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .creamBackground()
            .navigationTitle(pro.isPro ? "History" : "Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Pro totals

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 28) {
                figure("This week", Stats.total(sessions, in: .weekOfYear))
                figure("This month", Stats.total(sessions, in: .month))
            }
            WeekStrip(days: Stats.daily(sessions, days: 7))
        }
        .padding(.vertical, 8)
        .listRowBackground(Theme.creamDeep.opacity(0.5))
    }

    private func figure(_ caption: String, _ total: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption).labelStyle()
            Text(Stats.format(total))
                .font(.rounded(.title2, .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Rows

    private func row(_ session: Session) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(session.counts ? Theme.green : Theme.rule)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(Stats.format(session.elapsed))
                    .font(.rounded(.body, .semibold))
                    .foregroundStyle(Theme.ink)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.plain(.footnote))
                    .foregroundStyle(Theme.inkSoft)
                if let label = session.label, !label.isEmpty {
                    Text(label)
                        .font(.plain(.footnote))
                        .foregroundStyle(Theme.green)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(session.outcome.display)
                .font(.rounded(.caption, .semibold))
                .foregroundStyle(session.counts ? Theme.green : Theme.inkSoft)
        }
        .listRowBackground(Theme.creamDeep.opacity(0.5))
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nothing yet").labelStyle()
            Text("Finish a block and it shows up here.")
                .font(.plain(.subheadline))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Seven days of kept time. Hand-drawn rather than charted: Swift Charts is a
/// system framework, but the house rule is a short dependency list, and this is
/// twenty lines.
private struct WeekStrip: View {
    let days: [Stats.DayTotal]

    private var peak: TimeInterval { max(days.map(\.total).max() ?? 0, 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(day.total > 0 ? Theme.green : Theme.rule)
                        .frame(height: height(for: day.total))
                    Text(day.day.formatted(.dateTime.weekday(.narrow)))
                        .font(.rounded(.caption2, .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(day.day.formatted(.dateTime.weekday(.wide))): \(Stats.format(day.total))"
                )
            }
        }
        .frame(height: 58, alignment: .bottom)
    }

    private func height(for total: TimeInterval) -> CGFloat {
        let scaled = CGFloat(total / peak) * 40
        return max(3, scaled)
    }
}

private struct PaywallRow: View {
    @State private var show = false

    var body: some View {
        Button {
            show = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Everything before today")
                    .font(.rounded(.callout, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Full history, weekly and monthly totals, labels.")
                    .font(.plain(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.creamDeep.opacity(0.5))
        .sheet(isPresented: $show) { PaywallView() }
    }
}

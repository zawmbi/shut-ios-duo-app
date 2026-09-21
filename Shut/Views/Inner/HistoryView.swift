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
                if visible.isEmpty {
                    empty
                } else {
                    List {
                        Section {
                            ForEach(visible) { session in
                                row(session)
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

    private func row(_ session: Session) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(session.counts ? Theme.green : Theme.rule)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(Stats.format(session.elapsed))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer()

            Text(session.outcome.display)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(session.counts ? Theme.green : Theme.inkSoft)
        }
        .listRowBackground(Theme.creamDeep.opacity(0.5))
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nothing yet").labelStyle()
            Text("Finish a block and it shows up here.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSoft)
        }
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Full history, weekly and monthly totals, labels.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.creamDeep.opacity(0.5))
        .sheet(isPresented: $show) { PaywallView() }
    }
}

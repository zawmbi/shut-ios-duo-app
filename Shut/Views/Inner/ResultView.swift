import SwiftUI
import SwiftData

struct ResultView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(Entitlements.self) private var pro
    @Environment(\.modelContext) private var context

    @State private var label: String = ""

    private var session: Session? { engine.lastFinished }
    private var kept: Bool { engine.phase == .complete }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(kept ? "Kept" : "Broken").labelStyle()

            Text(Stats.format(session?.elapsed ?? 0))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(kept ? Theme.green : Theme.ink)
                .padding(.top, 4)
                .accessibilityLabel(
                    "\(kept ? "Kept" : "Broken"). \(Stats.spoken(session?.elapsed ?? 0))."
                )

            if let session, session.interruptions > 0 {
                Text(session.interruptions == 1
                     ? "Opened once."
                     : "Opened \(session.interruptions) times.")
                    .font(.plain(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }

            // Pro only, and deliberately the only thing Pro adds to this
            // screen: the paywall never appears at the moment a block ends.
            if pro.isPro, session != nil {
                labelField
            }

            Spacer()

            Button("Done") {
                commitLabel()
                engine.acknowledge()
            }
            .font(.rounded(.body, .semibold))
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.green)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .creamBackground()
        .onAppear { label = session?.label ?? "" }
    }

    private var labelField: some View {
        TextField("Label", text: $label)
            .font(.plain(.subheadline))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .onSubmit { commitLabel() }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Theme.creamDeep)
            .clipShape(Capsule())
            .padding(.top, 24)
            .padding(.horizontal, 40)
            .accessibilityLabel("Label for this block")
    }

    private func commitLabel() {
        guard let session else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        session.label = trimmed.isEmpty ? nil : trimmed
        try? context.save()
    }
}

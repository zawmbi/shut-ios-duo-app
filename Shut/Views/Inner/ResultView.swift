import SwiftUI
import SwiftData

struct ResultView: View {
    @Environment(SessionEngine.self) private var engine
    @Environment(Entitlements.self) private var pro
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @AppStorage(PrefKey.encouragement) private var encourage = false

    @State private var label: String = ""

    private var session: Session? { engine.lastFinished }
    private var kept: Bool { engine.phase == .complete }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // A full disc for a kept block, half of one for a broken block.
            // Shape, not colour, carries the outcome; the label says it too.
            Group {
                if kept {
                    Circle().fill(palette.secondary)
                } else {
                    HalfDisc().fill(palette.rule)
                        .frame(height: 36)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            Text(kept ? "Kept" : "Broken").labelStyle()

            Text(Stats.format(session?.elapsed ?? 0))
                .font(.numerals(64, .heavy))
                .foregroundStyle(kept ? palette.primaryText : palette.ink)
                .padding(.top, 4)
                // The "Kept"/"Broken" line above already says the outcome, so
                // this reads only the duration and VoiceOver doesn't say it twice.
                .accessibilityLabel(Stats.spoken(session?.elapsed ?? 0))

            if let session, session.interruptions > 0 {
                Text(session.interruptions == 1
                     ? "Opened once."
                     : "Opened \(session.interruptions) times.")
                    .font(.plain(.subheadline))
                    .foregroundStyle(palette.inkSoft)
                    .padding(.top, 8)
            }

            if encourage {
                Text(Encouragement.line(for: kept ? .kept : .broken, seed: session?.startedAt))
                    .font(.plain(.callout, .semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 32)
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
            .font(.plain(.body, .bold))
            .tracking(1)
            .foregroundStyle(palette.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(palette.primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .onAppear { label = session?.label ?? "" }
    }

    private var labelField: some View {
        TextField("Label", text: $label)
            .font(.plain(.subheadline))
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .onSubmit { commitLabel() }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

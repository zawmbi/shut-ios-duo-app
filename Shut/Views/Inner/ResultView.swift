import SwiftUI

struct ResultView: View {
    @Environment(SessionEngine.self) private var engine

    var body: some View {
        let session = engine.lastFinished
        let kept = engine.phase == .complete

        VStack(spacing: 0) {
            Spacer()

            Text(kept ? "Kept" : "Broken").labelStyle()

            Text(Stats.format(session?.elapsed ?? 0))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(kept ? Theme.green : Theme.ink)
                .padding(.top, 4)

            if let session, session.interruptions > 0 {
                Text(session.interruptions == 1
                     ? "Opened once."
                     : "Opened \(session.interruptions) times.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }

            Spacer()

            Button("Done") { engine.acknowledge() }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
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
    }
}

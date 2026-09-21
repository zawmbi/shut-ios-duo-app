import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro

    private let features = [
        ("Full history", "Every block you've kept, not just today's."),
        ("Weeks and months", "Totals and trends over time."),
        ("Labels", "Tag a block so you know what it went to."),
        ("Custom lengths", "Any duration, not just the presets."),
        ("Faces", "Digits and bar, as well as the ring."),
        ("Grace period", "Set how long you get before a block breaks.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One payment").labelStyle()
                        Text("Shut Pro")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("No subscription. Nothing leaves your phone, before or after.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.0) { title, detail in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.green)
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                    Text(detail)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .creamBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { if await pro.purchase() { dismiss() } }
                    } label: {
                        Text(pro.purchasing ? "…" : "Buy for \(pro.priceText)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(pro.purchasing || pro.product == nil)

                    Button("Restore purchase") { Task { await pro.restore() } }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(Theme.cream)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await pro.load() }
            .onChange(of: pro.isPro) { _, isPro in if isPro { dismiss() } }
        }
    }
}

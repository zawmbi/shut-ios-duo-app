import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Entitlements.self) private var pro
    @Environment(\.palette) private var palette

    private let features = [
        ("Full history", "Every block you've kept, not just today's."),
        ("Weeks and months", "Totals and trends over time."),
        ("Labels", "Tag a block so you know what it went to."),
        ("Custom lengths", "Any duration, not just the presets."),
        ("Faces", "Sunburst, digits and bar, as well as the ring."),
        ("Themes", "Avocado, Atomic and Dusk, as well as Walnut."),
        ("Grace period", "Set how long you get before a block breaks."),
        ("Forgiving streak", "One missed day a week doesn't reset it. Free forgives the first one.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One payment").labelStyle()
                        Text("Shut Pro")
                            .font(.plain(.largeTitle, .black))
                            .foregroundStyle(palette.ink)
                        Text("No subscription. Nothing leaves your phone, before or after.")
                            .font(.plain(.subheadline))
                            .foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.0) { title, detail in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(palette.secondary)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title)
                                        .font(.plain(.callout, .bold))
                                        .foregroundStyle(palette.ink)
                                    Text(detail)
                                        .font(.plain(.footnote))
                                        .foregroundStyle(palette.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .paperBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { if await pro.purchase() { dismiss() } }
                    } label: {
                        Text(pro.purchasing ? "…" : "Buy for \(pro.priceText)")
                            .font(.plain(.body, .bold))
                            .tracking(1)
                            .foregroundStyle(palette.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(palette.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(pro.purchasing || pro.product == nil)

                    Button("Restore purchase") { Task { await pro.restore() } }
                        .font(.plain(.footnote))
                        .foregroundStyle(palette.inkSoft)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(palette.paper)
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

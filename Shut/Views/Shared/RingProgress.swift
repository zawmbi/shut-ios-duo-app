import SwiftUI

/// A heavy ring with a band of hour-marker ticks around it, like a wall clock.
struct RingProgress: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var indeterminate: Bool = false
    var track: Color
    var fill: Color
    var ticks: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            TickRing(count: 12)
                .stroke(ticks, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            Circle()
                .stroke(track, lineWidth: lineWidth)
                .padding(lineWidth + 6)
            Circle()
                .trim(from: 0, to: indeterminate ? 1 : max(0.001, min(1, progress)))
                .stroke(
                    indeterminate ? track : fill,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .padding(lineWidth + 6)
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: progress)
        }
        .accessibilityHidden(true)
    }
}

/// Short radial marks around the edge of the frame.
struct TickRing: Shape {
    var count: Int
    var length: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi - .pi / 2
            let (dx, dy) = (cos(a), sin(a))
            p.move(to: CGPoint(x: c.x + dx * (outer - length), y: c.y + dy * (outer - length)))
            p.addLine(to: CGPoint(x: c.x + dx * outer, y: c.y + dy * outer))
        }
        return p
    }
}

/// Spokes radiating from a hub, lit clockwise as the block progresses. The
/// mid-century starburst clock, drawn as a progress indicator.
struct Sunburst: View {
    var progress: Double
    var indeterminate: Bool
    var lit: Color
    var unlit: Color
    var hub: Color
    var spokes: Int = 24

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let litCount = indeterminate ? spokes : Int((progress * Double(spokes)).rounded(.up))
            ZStack {
                ForEach(0..<spokes, id: \.self) { i in
                    // Alternate long and short spokes, as the clocks did.
                    let long = i.isMultiple(of: 2)
                    Capsule()
                        .fill(i < litCount ? lit : unlit)
                        .frame(width: long ? 5 : 3, height: side * (long ? 0.2 : 0.13))
                        .offset(y: -side * (long ? 0.4 : 0.435))
                        .rotationEffect(.degrees(Double(i) / Double(spokes) * 360))
                }
                Circle()
                    .fill(hub)
                    .frame(width: side * 0.54, height: side * 0.54)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

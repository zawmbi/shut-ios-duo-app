import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
//  ⚠️  VERIFY BEFORE TRUSTING — Milestone 0
//
//  This file is the ONLY place that touches iPhone Duo hinge APIs, and it is
//  written from Apple's published documentation rather than from a compiler.
//  The symbol name `onHingeChange` is confirmed; the exact shape of the context
//  it hands back is NOT. Before building anything on top of this:
//
//    1. Open the iPhone Duo simulator in Xcode 27.1.
//    2. Option-click `onHingeChange` and read the real signature.
//    3. Fix the body of `duoHingeReader` below to match.
//    4. Run, rotate through every pose, and confirm the printed posture.
//    5. Write what you found into FINDINGS.md.
//
//  The whole project compiles and runs WITHOUT this code path. Build with
//  `-D DUO_SDK` (Build Settings ▸ Other Swift Flags) only once step 3 is done.
//  Until then the app is a working lock-to-focus timer on any iPhone, which is
//  also exactly what it must be on non-Duo hardware in the shipped build.
// ─────────────────────────────────────────────────────────────────────────────

extension View {
    /// Attaches the hinge observer on Duo; a no-op everywhere else.
    func hingeAware(_ monitor: HingeMonitor) -> some View {
        modifier(HingeAware(monitor: monitor))
    }
}

private struct HingeAware: ViewModifier {
    let monitor: HingeMonitor

    func body(content: Content) -> some View {
        #if DUO_SDK
        if #available(iOS 27.1, *) {
            content.onHingeChange { context in
                // VERIFY: `context.hinge` is nil on every non-Duo iPhone. That
                // nil check is the single most important line in the app — it
                // is what lets one binary serve both device families.
                guard let hinge = context.hinge else {
                    monitor.ingestHinge(isFoldable: false, posture: .open)
                    return
                }
                // VERIFY: confirm the case names on the coarse status enum.
                // Apple's prose calls them closed / partially open / fully open.
                // We deliberately ignore the continuous angle the context also
                // carries: we cannot test angle precision without hardware, and
                // this product does not need it.
                let posture: HingeMonitor.Posture = switch hinge.status {
                case .closed:        .closed
                case .partiallyOpen: .partial
                default:             .open
                }
                monitor.ingestHinge(isFoldable: true, posture: posture)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

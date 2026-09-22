import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
//  VERIFIED against the iOS 27.1 SDK and the iPhone Duo simulator, 2026-09-21.
//  See FINDINGS.md §1 for the transcript. The signature below is the real one,
//  read out of SwiftUICore's .swiftinterface and exercised in a running app:
//
//      func onHingeChange(
//          isEnabled: Bool = true,
//          _ action: @escaping (_ oldContext: DeviceHingeContext,
//                               _ newContext: DeviceHingeContext) -> Void
//      ) -> some View
//
//  Two contexts, not one. `DeviceHinge.Status` is a struct with static members,
//  not an enum, so there is no exhaustive switch to write over it.
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
            content.onHingeChange { _, newContext in
                // The modifier fires once on appear with the posture the device
                // is already in — verified: the first delivery carries
                // `oldContext.hinge == nil` and a populated `newContext`. So
                // there is no seed read to write, and a phone that is already
                // shut when the app launches is reported as shut.
                //
                // A nil `newContext.hinge` does NOT mean "not a foldable". The
                // UIKit header for the equivalent `UIHingeInteraction` says nil
                // is also delivered when the observer "leaves a hierarchy that
                // provides hinge updates". Treating that as non-foldable would
                // silently downgrade a Duo mid-session, so `HingeMonitor`
                // latches: once a hinge has been seen, this stays a fold device.
                guard let hinge = newContext.hinge else {
                    monitor.ingestHingeUnavailable()
                    return
                }
                // `Status` is a struct of static members, so this is `==`, not
                // enum matching. We ignore `hinge.angle` deliberately: the
                // product only needs shut vs not-shut, and Apple's own header
                // says to prefer `status` over the angle for exactly that.
                let posture: HingeMonitor.Posture =
                    if hinge.status == .closed { .closed }
                    else if hinge.status == .partiallyOpen { .partial }
                    else { .open }
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

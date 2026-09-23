# Findings

Fill this in during Milestone 0. Everything below is an open question that the
source tree currently guesses at. Nothing else should be built until these are
answered.

> **Status: all four questions are answered.** Verified 2026-09-21 against the
> iOS 27.1 SDK (**Xcode 27.1 beta**, build 27A9269) and a booted iPhone Duo
> simulator, by reading the
> real `.swiftinterface` and by running instrumented code on the device. The
> headline: **Plan B is not needed.** The app keeps running when the phone is
> shut, on the cover display, and `-D DUO_SDK` now compiles and runs.
>
> Two of the guesses this file was written to check were wrong, and one line in
> `CLAUDE.md` is wrong. Both are recorded below. `Core/HingeBridge.swift` and
> `Core/HingeMonitor.swift` have been corrected; `App/ShutApp.swift` still needs
> its second-scene comment deleted (§2).

## Toolchain — recorded 2026-09-20 (superseded 2026-09-21)

> Historical. Xcode 27.1 landed on 2026-09-21 and the blocker below is gone —
> see "Milestone 0 — answered". Kept because it records what was true on the
> 26.6 machine, and because its last paragraph's advice was right.


The first Mac to open this repository had **Xcode 26.6** (build 17F113, Swift
6.3.3), iOS 26.5 SDK, and no other Xcode installed. That is below the floor
`CLAUDE.md` sets, and it blocks Milestone 0 outright:

- `simctl list devicetypes` reports **no fold / duo / flip device type**. iOS 26.5
  is the only installed runtime, so there is no Duo simulator to pose.
- `onHingeChange`, `reservedRegions` and `foldState` **do not appear anywhere in
  the iOS 26.5 SDK** — not in SwiftUI, not in UIKit. (A grep for `hinge` against
  the UIKit headers matches only `isPrefetchingEnabled`. It is a substring, not an
  API.)

This is consistent with `CLAUDE.md` — those symbols are expected in the iOS 27.1
SDK — and it is not evidence either way about question 2. **Milestone 0 cannot
begin until Xcode 27.1 is installed.** Do not read the absence of these symbols on
26.5 as a Plan B trigger; the Plan B decision needs the 27.1 SDK to be made at all.

### First build, 2026-09-20

Against Xcode 26.6 / iOS 26.5, scheme `Shut`, iPhone 16 Pro Max simulator, Debug,
`DUO_SDK` off: **BUILD SUCCEEDED**, no warnings. This is a validity check on the
Swift, **not** a shippable configuration — `CLAUDE.md` forbids shipping anything
built against Xcode 26, which letterboxes the app on Duo.

One error, in two places, both the same cause: a nonisolated `deinit` on a
`@MainActor @Observable` class referencing an isolated stored property, which
Swift 6 rejects.

- `Core/SessionClock.swift:30` — `task`
- `Store/Entitlements.swift:29` — `updates`

Fixed with `isolated deinit` (SE-0371) rather than `HANDOFF.md`'s suggestion of
dropping the `deinit`. Dropping it would strand the 250 ms tick loop in
`SessionClock` and the `Transaction.updates` stream in `Entitlements` after
dealloc — both are `while`/`for await` loops that only a cancel ends, and `[weak
self]` stops them touching state without stopping them spinning.
`nonisolated(unsafe)` also compiles and was rejected as the weaker option: it
silences the check instead of satisfying it.

The other five failure points `HANDOFF.md` predicted — `SessionClock.start()`'s
redundant `MainActor.run`, the `switch` expression in `SessionEngine.finish(as:)`,
`Theme.swift`'s font helpers, the StoreKit configuration path in the shared
scheme, and `GeometryProxy.reservedRegions` behind the flag — all compiled clean
and need no action.

`Tools/logic-check/` still passed at this point, 55 cases, both suites.

### Test target, 2026-09-20

`Tools/logic-check/` is gone, replaced by `ShutTests` — 45 tests, 57 assertions,
green on the iPhone 16 Pro Max simulator. Swift Testing rather than XCTest: the
cases are table-driven, and `@Test` gives each one the name and per-case failure
that the Python harness's `check(name, got, want)` produced. XCTest would have
meant 45 near-identical methods or one method with 57 assertions and no way to
tell which failed. Both ship with Xcode; no dependency was added.

Two things `HANDOFF.md` and `DEFERRED.md` asserted turned out to be wrong, and
the port is where they surfaced:

- **`SessionEngine` did not take an injectable date.** It read `Date.now` in six
  places, so none of its behaviour could be tested without waiting in real time.
  It now holds a `@MainActor () -> Date` seam, defaulting to the wall clock.
  Production behaviour is unchanged; the tests substitute a fake and drive it
  across three hours in milliseconds. `Stats` was genuinely injectable, as
  claimed.
- **The DST cases are weaker in Swift than in Python.** `Stats` reads
  `Calendar.current` and cannot be handed a fixed calendar, so the spring-forward
  and fall-back cases only cross a real transition on a machine in a US time
  zone. Everywhere else they still prove the streak steps by calendar days rather
  than 86,400-second jumps. Giving `Stats` a calendar seam would fix it and was
  judged not worth a production change for two cases — noted here so the decision
  is visible rather than silent.

## Milestone 0 — answered 2026-09-21

Method: read `SwiftUICore.framework`'s `arm64-apple-ios-simulator.swiftinterface`
and UIKit's headers out of the iOS 27.1 SDK, then compiled and ran an
instrumented SwiftUI app on a booted `iPhone Duo` simulator and read its console
and framebuffers. Anything below that was reasoned rather than observed says so.

## 1. `onHingeChange` — real signature

- [x] **What type does the closure receive?** Two of them, not one:

      @available(anyAppleOS 27.1, *)
      extension View {
          nonisolated public func onHingeChange(
              isEnabled: Bool = true,
              _ action: @escaping (_ oldContext: DeviceHingeContext,
                                   _ newContext: DeviceHingeContext) -> Void
          ) -> some View
      }

  **This file's guess was wrong.** The old `HingeBridge` wrote
  `onHingeChange { context in … }` — a single parameter. It would not have
  compiled. It now takes `{ _, newContext in … }`.

  Note it lives in **SwiftUICore**, not SwiftUI. That matters only if you go
  looking: `import SwiftUI` re-exports it, so nothing changes at the call site.

- [x] **Is the property `context.hinge`? Is it Optional?** Yes and yes.

      public struct DeviceHingeContext: Equatable, Sendable {
          public var hinge: DeviceHinge?
      }
      public struct DeviceHinge: Hashable, Sendable {
          public var status: DeviceHinge.Status
          public var angle: Angle          // SwiftUI Angle, not a raw Double
      }

- [x] **What are the case names on the coarse status enum?** There is no enum.
      `DeviceHinge.Status` is a **struct** with three static members —
      `.closed`, `.partiallyOpen`, `.fullyOpen` — and `Hashable` conformance.

      There is **no `.unknown`** on the SwiftUI type, though UIKit's
      `UIHinge.Status` does have `unknown = 0`. You cannot write an exhaustive
      switch over it; `HingeBridge` now compares with `==` and falls through to
      `.open`, which is the safe default (it never starts a block by accident).

- [x] **Does it fire once on appear with the current posture, or only on change?**
      **It fires on appear.** Observed first delivery, before any pose change:

          [onHingeChange #1] old=hinge=nil new=hinge(status=closed, angle=0.0°)

      So `oldContext.hinge` is nil on that first call and `newContext.hinge`
      carries the posture the device is already in. **No seed read is needed**,
      and the failure this file worried about — `HingeMonitor` sitting in
      `.armed` forever on a phone that is already shut — does not happen.

**Fixed in:** `Core/HingeBridge.swift`, `Core/HingeMonitor.swift`.

### The UIKit path, for reference

`UIHingeInteraction` was also exercised and behaves the same way:

    let interaction = UIHingeInteraction { _, update in
        guard let hinge = update.hinge else { return }   // nullable
        // hinge.status: UIHinge.Status — unknown/closed/partiallyOpen/fullyOpen
        // hinge.angle:  CGFloat, in radians
    }
    view.addInteraction(interaction)

Observed: `status=1` (closed), `angle=0.0`, delivered once on add. We do not use
it — SwiftUI's modifier is enough — but it is the ground truth if the SwiftUI
path ever misbehaves.

**One caveat worth keeping.** `update.hinge == nil` does **not** mean "this is
not a foldable". Apple's header documents nil as *also* meaning the observer
"leaves a hierarchy that provides hinge updates". The old `HingeBridge` treated
nil as "not a Duo" and cleared `isFoldable`, which would have silently demoted a
Duo to the lock-based path mid-session. `HingeMonitor.isFoldable` now **latches
on** and nil is a no-op that leaves posture untouched.

## 2. Outer display

- [x] **Does the app keep executing when the phone is folded shut?** **Yes.**
      The Duo simulator boots closed. Both the throwaway spike and `Shut` itself
      launched, ran and rendered while `status == .closed`, on the cover display.
      A framebuffer capture of the cover display shows live app UI; the inner
      display was black.

- [x] **What is the API for presenting different content on the outer display?**
      **There isn't one, and you don't need one.**

      There is no outer-display scene API in the iOS 27.1 SDK. SwiftUI has no
      such `Scene` type; UIKit's only external-display session roles are the
      pre-existing `UIWindowSceneSessionRoleExternalDisplayNonInteractive`
      (iOS 16, for AirPlay and monitors) and its deprecated predecessor. Neither
      is the cover display.

      Instead the system **moves your one scene between the two displays.**
      Measured from inside the running app while shut:

          connectedScenes   = 1
          scene role        = UIWindowSceneSessionRoleApplication
          UIScreen.screens  = 1
          screen bounds     = 466 × 678 pt @3x   (cover)

      The Duo profile declares two integrated displays — `primary`
      1398×2034 @3x (cover, 466×678 pt) and `primary-1` 2007×2853 @3x (inner,
      669×951 pt) — but an app only ever sees the one it is currently on.
      SpringBoard's own display-swap tooling describes the model exactly: *"a
      display swap occurs only if the sweep crosses the swap boundary (e.g. book
      from closed swaps cover to inner; book from open does not swap)."*

- [x] **Is it a separate `Scene`, a role on `WindowGroup`, or something else?**
      **Something else: neither.** One `WindowGroup`, which the system relocates.
      "Which face do I show" is therefore an ordinary view-level branch on
      `HingeMonitor.posture` inside `RootView`, not a second scene.

- [ ] **Does the outer display stay lit, or does it sleep on the usual timeout?**
      **Not determined, and do not claim it either way in store copy.** The cover
      display stayed lit and rendering for the whole session with no idle
      blanking observed, and the inner display was powered down throughout — but
      the simulator does not model real backlight or idle policy, so this proves
      nothing about battery. Re-test on hardware on Oct 23 before the battery
      story goes in the App Store description.

**Plan B is not triggered.** The premise holds: one `WindowGroup`, the app keeps
executing shut, and what the cover display shows is simply what the app draws.

**Still to fix in `App/ShutApp.swift`:** delete the second-scene comment block
and its Plan B note. There is no second scene to add. `Views/Outer/TimerFaceView`
stays exactly where it is — it just gets presented by `RootView` when
`posture == .closed` rather than by a scene of its own.

## 3. `reservedRegions`

- [x] **Exact signature on `GeometryProxy`.** As documented, no surprises:

      @available(anyAppleOS 27.1, *)
      extension GeometryProxy {
          public func reservedRegions(
              kind: ReservedRegion.Kind,
              options: ReservedRegion.QueryOptions = [],
              layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors
          ) -> [ReservedRegion]
      }

      `ReservedRegion` carries `id`, `kind`, `frame: CGRect`,
      `margins: EdgeInsets` and `isActive: Bool`. `QueryOptions` is an
      `OptionSet` whose only member is `.includeInactive`.

- [x] **Case names for the `kind` parameter.** `.division` and `.occlusion`, as
      the docs said. Like `Status`, `ReservedRegion.Kind` is a struct of static
      members, not an enum.

- [x] **Does the outer display report an occlusion for its camera?** **No.**
      Measured on the cover display while closed, both kinds, with and without
      `.includeInactive`:

          reservedRegions(.division)  active=0  all=0
          reservedRegions(.occlusion) active=0  all=0

      So `ReservedInsets` in `TimerFaceView` gets an empty array on the cover
      display and must lay out correctly with no regions at all. It must not
      assume a camera occlusion exists.

      What *does* eat space on the cover display is the status bar, which is
      rendered as a **vertical bar on the trailing edge** — the thing
      `toolbarVerticalEdge` (SwiftUI) and `UIVerticalBarEdge` (UIKit) describe.
      It arrives as safe-area inset, not as a reserved region: the screen is
      466×678 pt and the content rect measured 386×644 pt, i.e. ~80 pt taken on
      one horizontal edge. Honour safe areas and it is handled.

      **Not measured in the open pose** — see §4 for why. The fold `.division`
      region in particular can only be non-empty when the phone is partly open,
      so it remains unobserved.

## 4. Simulator behaviour

- [x] **Does the simulator report a hinge at all, or is `context.hinge` nil
      there too?** **It reports one.** `context.hinge` is non-nil in the Duo
      simulator, with a real status and angle, and `UIHingeInteraction` delivers
      as well. The real path is testable before Oct 23 — this was the worst case
      in the original question and it did not happen.

- [~] **Which poses does the Duo simulator expose, and how do you trigger them?**
      Answered for *what exists*, blocked for *how to drive it here*.

      The runtime's vocabulary is **closed / book (~100°) / open**, plus any
      continuous position in `[0.0, 1.0]`. It is driven by SpringBoard's
      display-swap tool, `suiatool`, whose flags are `-duration=<seconds>`,
      `-orientation=…`, `-position=<closed|book|open|0.0-1.0>`,
      `-fade` | `-continuous`, and `-wait`.

      **No pose can be set headlessly**, which is the honest limit of this
      session: `suiatool` is not shipped in the runtime — only the strings that
      describe it are — and `simctl` has no pose or hinge verb. Driven from the
      command line, the device sits in whatever pose it boots in, which is
      **closed**.

      **Correction.** An earlier draft of this section claimed Simulator.app was
      not installed. That was wrong, and the mistake was looking in the Xcode 26
      location. Xcode 27 ships the simulator GUI as **`DeviceHub.app`**, at
      `Contents/Applications/DeviceHub.app` — present in *both* Xcodes here, as
      is Icon Composer. The old `Contents/Developer/Applications` directory no
      longer exists in either, which is what misled the check. `HANDOFF.md` is
      right: Device Hub is where the Duo simulator and its pose control live,
      and it is GUI-only, so it needs a human in front of it. That is the single
      remaining step of Milestone 0, not a missing install.

      Consequence: everything above about the *closed* pose is measured;
      nothing about the open or partially-open pose is. The fold `.division`
      region, the swap transition itself, and how `onHingeChange` behaves across
      a swap are all still unobserved. **Getting Simulator.app onto this machine
      is the next real task**, and it is what unblocks the rest of Milestone 0.

      **Done, 2026-09-23.** Driven by hand in Device Hub, `DUO_SDK` build. The
      end-of-day-1 test passes with the fold: arm 1 min, shut, wait, open →
      **Kept — 1m**; arm, shut, open, let grace expire → **Broken**. So
      `onHingeChange` does deliver across the cover/inner swap and the engine
      follows it. The `.division` region in the book pose was not reported on
      and is still unobserved.

- [x] **A second limit worth knowing.** The installed iOS 27.1 runtime supports
      **exactly one device type: iPhone Duo.** `simctl` refuses to create an
      iPhone 17, 17 Pro, 18 Pro or 17e against it. So the nil-hinge branch — the
      universal-build rule, "the single most important line in the app" — cannot
      be exercised on 27.1 here at all. It stays unverified on a non-foldable
      device running an OS that has the API.

## Corrections to `CLAUDE.md`

1. **The SwiftUI hinge signature.** The API table says
   `.onHingeChange { context in … }`. It takes **two** contexts, old and new.
2. **The simulator's poses.** "Pose controls for closed / tent / laptop /
   partially folded / fully open" does not match the runtime, whose vocabulary
   is closed / book / open plus a continuous 0.0–1.0 position. There is no tent
   or laptop pose.
3. **"It's a scene-level API, not a view modifier"** (under *APIs to verify*) is
   wrong in a way that is good news: there is no outer-display API at all,
   because the system relocates the app's single scene. Item 3 of that list,
   `CameraCaptureAccessory`, is therefore moot and can be struck.

Everything else in the API table checked out: `GeometryProxy.reservedRegions`,
`UIView.reservedRegionsOfKind:options:`, `UIArrangementViewController`,
`EnvironmentValues.toolbarVerticalEdge`, `UITraitCollection.verticalBarEdge` and
`ArrangementView` all exist with the names given.

### Build, 2026-09-21 — the Duo path compiles

`xcodebuild -scheme Shut -destination "platform=iOS Simulator,id=<Duo>" \
  OTHER_SWIFT_FLAGS="-D DUO_SDK"` → **BUILD SUCCEEDED**, and the app installs,
launches and renders on the Duo cover display. This is the first time the
`DUO_SDK` path has been through a compiler.

`-D DUO_SDK` is still **not** set in the Xcode project. Set it once a pose
change has actually been observed. (§2's `ShutApp.swift` cleanup is done.)

**This build is not submittable, and that is expected.** Xcode 27.1 is a beta,
so Apple will not accept an App Store build made with it — see `HANDOFF.md`'s
toolchain table and the v1.0 / v1.1 split. Milestone 0 is development, not
submission, so the beta is the right tool for everything in this file. v1.0
archives on the **Xcode 27.0 release** with `DUO_SDK` off; the hinge ships in
v1.1 once 27.1 is final.

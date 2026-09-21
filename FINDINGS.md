# Findings

Fill this in during Milestone 0. Everything below is an open question that the
source tree currently guesses at. Nothing else should be built until these are
answered.

> **Status: every question below is still open.** They need Xcode 27.1, the
> iPhone Duo simulator and the SDK headers, and a Mac with Xcode 26.6 does not
> have them — see "Toolchain" below. The tree **has** now been through a compiler
> on the plain-iPhone path, so it is no longer unverified Swift; but
> `Core/HingeBridge.swift` and the outer-display scene in `App/ShutApp.swift` are
> still guesses, because nothing in this file has been answered. `-D DUO_SDK` is
> deliberately **not** set in the Xcode project for that reason.

## Toolchain — recorded 2026-09-20

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

`Tools/logic-check/` still passes, 55 cases, both suites.

## 1. `onHingeChange` — real signature

- [ ] What type does the closure receive?
- [ ] Is the property `context.hinge`? Is it Optional?
- [ ] What are the case names on the coarse status enum?
- [ ] Does it fire once on appear with the current posture, or only on change?
      (If only on change, `HingeMonitor` needs a seed read — the app will
      otherwise sit in `.armed` forever on a phone that is already shut.)

**Fix in:** `Core/HingeBridge.swift`

## 2. Outer display

- [ ] Does the app keep executing when the phone is folded shut?
- [ ] What is the API for presenting different content on the outer display?
- [ ] Is it a separate `Scene`, a role on `WindowGroup`, or something else?
- [ ] Does the outer display stay lit, or does it sleep on the usual timeout?
      If it sleeps, the face needs an idle-timer decision and that changes the
      battery story in the App Store copy.

**Fix in:** `App/ShutApp.swift`

**Plan B trigger:** if there is no usable outer-display scene, say so here, delete
the second scene, and ship on local notifications. Decide within the first hour.

## 3. `reservedRegions`

- [ ] Exact signature on `GeometryProxy`.
- [ ] Case names for the `kind` parameter (docs say `.division` and `.occlusion`).
- [ ] Does the outer display report an occlusion for its camera?

**Fix in:** `Views/Outer/TimerFaceView.swift` (`ReservedInsets`)

## 4. Simulator behaviour

- [ ] Which poses does the Duo simulator expose, and how do you trigger them?
- [ ] Does the simulator report a hinge at all, or is `context.hinge` nil there
      too? (If nil, there is no way to test the real path before Oct 23 — note
      it, and keep the lock-based path as the one you actually verify.)

# Handoff

State of the branch `claude/new-session-of2kze`, and what to do on the Mac.

**Read this first: nothing in this repository has been compiled.** The Xcode
project, and every change after the source tree first landed, was written in a
Linux container with no Swift toolchain and no Xcode. The Swift is unverified,
the project file has never been opened, and the first build should be expected
to need fixing. That is the normal state of this branch, not a warning sign.

---

## What is done

- The source tree, plus `Shut.xcodeproj` — one app target, iOS 26.0 deployment,
  Swift 6 language mode, iPhone only, `Shut/` as a file-system-synchronized
  group, shared scheme wired to `Products.storekit`, asset catalogue with the
  accent colour and an **empty** app-icon slot.
- Three engine bugs fixed. The worst recorded a finished block as *Broken*: a
  block that reached its target while the phone was shut was still `.running`
  when the phone opened, so it read as an interruption and grace expired.
- Two preferences that were written but never read: the grace-period stepper had
  no effect on the engine at all, and the sound toggle never reached the
  notification.
- Every paywall claim now matches the binary. Custom lengths, week and month
  totals, labels and the face picker were built; iCloud sync was cut. See
  `DEFERRED.md`.
- The accessibility pass: Dynamic Type, VoiceOver labels, reduce-motion.
- `Tools/logic-check/` — `Stats` and `SessionEngine` ported to Python, running
  the day-boundary and state-machine cases including BUILD.md's end-of-day-1
  test. 55 cases, all passing. It proves the algorithm and never the Swift.

## What is not done

- **Milestone 0.** Entirely open. Every question in `FINDINGS.md` is unanswered
  and both VERIFY banners stand. `-D DUO_SDK` is deliberately not set.
- No compile, ever. No simulator run. No StoreKit test.
- No XCTest target. No app icon art. No screenshots or metadata.

---

## Do these in order

### 1. Milestone 0, first, before touching anything else

Unchanged from `BUILD.md`. New blank SwiftUI app, attach `.onHingeChange`, print
what it hands back, rotate through every pose, and answer the four questions in
`FINDINGS.md` from what you actually see. Then find out whether the app keeps
executing when folded and what the outer display shows — that is question 2 and
it decides the product.

**Write the answers into `FINDINGS.md` as you go, and delete the status banner at
the top of that file when they are all answered.** Port the corrections into
`Core/HingeBridge.swift` and `App/ShutApp.swift`, and only then set `-D DUO_SDK`.

If there is no usable outer-display scene, take Plan B in the first hour: single
window, local notification at the target time, recompute from `startedAt` on
foreground. The engine already works that way, so it is a deletion. Write the
decision down in `FINDINGS.md` either way.

### 2. First build, plain-iPhone path, `DUO_SDK` off

This is the path that ships to every non-Duo iPhone and the one App Review will
test, so it has to work regardless of what Milestone 0 found.

You will need to set the signing team on the target — it is not in the project.
Check `PRODUCT_BUNDLE_IDENTIFIER` (`xyz.zawmbi.shut`) against App Store Connect
before the first archive.

Most likely to break, in rough order. All are guesses — nothing was compiled:

- **`deinit` under strict concurrency** in `Core/SessionClock.swift` and
  `Store/Entitlements.swift`. Both touch a `Task` property from a nonisolated
  `deinit` on a `@MainActor` class. `Task` is Sendable so it should be allowed,
  but if Swift 6 rejects it, drop the `deinit` and cancel explicitly.
- **`SessionClock.start()`** wraps `self?.now = .now` in `MainActor.run` inside a
  `Task` that already inherits `@MainActor`. Redundant, and possibly a Sendable
  complaint. Deleting the `MainActor.run` wrapper is the fix.
- **The switch expression** in `SessionEngine.finish(as:)` (`let endedAt: Date =
  switch outcome {…}`). Needs Swift 5.9+; fine in 6, but it is the newest syntax
  in the tree.
- **`Font.rounded(_:_:)` / `Font.plain(_:_:)`** in `Views/Shared/Theme.swift`,
  used everywhere. If `Font.system(_:design:weight:)` resolves differently than
  expected, this is one file to fix and the whole app follows.
- **The StoreKit configuration path** in the shared scheme. If Xcode says the
  configuration is missing, re-pick `Products.storekit` in Scheme ▸ Run ▸ Options
  ▸ StoreKit Configuration. The relative path is the one thing in the project
  file that could not be checked.
- **`GeometryProxy.reservedRegions`** in `Views/Outer/TimerFaceView.swift` is
  inside `#if DUO_SDK`, so it cannot break the build until you set the flag.

### 3. Run BUILD.md's end-of-day-1 test on the simulator

Arm one minute, lock, wait, unlock: **Kept — 1m**. Arm again, lock, unlock after
ten seconds, wait out the grace: **Broken**. `Tools/logic-check/engine_check.py`
says both pass as logic; this is the run that says they pass as an app.

Then the same on the Duo simulator with the fold, if Milestone 0 said yes.

### 4. StoreKit in the simulator

Buy, restore, and each Pro gate: full history, week and month totals, labels on
the result screen, the Custom cell in the duration grid, the face picker, the
grace stepper. Then check the free tier still reads correctly — History titled
"Today", ring face only, grace fixed at 10s.

### 5. Replace `Tools/logic-check/` with an XCTest target

The cases are already written and named; port them and delete the directory.
`Stats` and `SessionEngine` both take an injectable date, which is why this is
quick.

### 6. Icon, screenshots, metadata, archive, submit

`Assets.xcassets/AppIcon.appiconset` has an empty 1024 slot — an archive will
complain until there is art in it. Screenshot list and store copy are in
`BUILD.md`; six shots, the fold visible in at least three.

Privacy nutrition label: **Data Not Collected**, every category. That is
verifiable in the tree — there is no `URLSession`, no CloudKit, no analytics.

---

## Things only you can do

- Apple account, signing, App Store Connect, the submission itself.
- The app icon.
- Screenshots — the hero shot is the phone folded shut with the outer display
  showing time remaining, and it cannot be faked from a non-Duo simulator.
- The featuring nomination, filed **the day it goes live**, not later. One
  sentence: this app is impossible on a phone that doesn't fold.
- The fifteen-second demo for Zawmbi's channels — shoot it once the simulator
  works; no hardware needed for the first one.

## Dates

Pre-orders **Oct 16**, device ships **Oct 23**. Being live before either is the
whole point.

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
- `ShutTests` — 45 tests, 57 assertions, all passing against the Swift itself.
  Replaced the Python stand-in, which is deleted. Covers the day-boundary and
  state-machine cases including BUILD.md's end-of-day-1 test.

## What is not done

- **Milestone 0.** Entirely open. Every question in `FINDINGS.md` is unanswered
  and both VERIFY banners stand. `-D DUO_SDK` is deliberately not set.
- No compile, ever. No simulator run. No StoreKit test.
- No XCTest target. No app icon art. No screenshots or metadata.

---

## Toolchain: you need two Xcodes, and neither is optional

Checked against Apple on 2026-09-21. This is the part most likely to be assumed
wrong, because `CLAUDE.md` says "Xcode 27.1 or later" and reads as though that is
a shipping release. It is not.

| | Duo SDK + simulator | Submittable to the App Store | Letterboxes on Duo |
|---|---|---|---|
| Xcode 26.x | no | yes, until Apr 2027 | **yes** |
| Xcode 27.0 release | no | yes | no |
| **Xcode 27.1 beta** | **yes** | **no — it is a beta** | no |

- **Xcode 27.1 is a beta**, build 27A9269, released 2026-09-18. It carries the
  iOS 27.1 SDK, Swift 6.4 and the iPhone Duo simulator (in Device Hub).
  developer.apple.com/download/all; a free developer account is enough.
- It needs **Apple silicon and macOS 26.6 or later**. Below that the GUI will not
  launch — LaunchServices error `-10825` — even though `xcodebuild` runs fine,
  because command-line tools skip the OS compatibility check. Device Hub is GUI,
  so the OS version is not optional.
- The **iOS 27.1 simulator runtime is a separate ~10 GB download**, from Xcode ▸
  Settings ▸ Components. Without it there is no Duo simulator at all. Check with
  `xcrun simctl list devicetypes | grep -i duo`.
- **App Store submissions currently take Xcode 27 RC / iOS 27.0 SDK builds.**
  Apple does not accept App Store builds made with a beta Xcode, and says
  uploading iPhone Duo assets to App Store Connect arrives "later this year".
  The iOS 27 SDK only becomes mandatory in April 2027.

### What that does to the ship plan

The launch dates assume a Duo build can ship before Oct 16. It cannot, yet. The
universal-build rule absorbs this at no cost, because both halves already had to
work:

- **v1.0, now.** Archive with **Xcode 27.0 release**, `DUO_SDK` off — the
  lock-to-focus timer that runs on every iPhone, which is the path App Review
  will test anyway. Live before pre-orders. Do **not** archive this with Xcode
  26.x: it letterboxes on Duo.
- **v1.1, when 27.1 goes final.** Flip `DUO_SDK` on, add the Duo screenshots,
  file the featuring nomination then.

Milestone 0 is unaffected — development, not submission — so do it on the beta
as soon as the OS allows.

Worth checking once the simulator runs: build v1.0 against the 27.0 SDK, install
it on the Duo simulator, and see whether it letterboxes. If it does, shipping
v1.0 first is still right, but v1.1 stops being merely next.

**Keep both Xcodes and don't keep flipping `xcode-select`.** Leave it on the
release Xcode — the one that archives submittable builds — and reach for the beta
per command, so an archive can't be cut with a beta toolchain by accident:

```
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl list devicetypes
```

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

**Settled on the first build, 2026-09-20.** The project opened, and the only
thing that failed was the first item below — two `deinit`s under strict
concurrency, fixed with `isolated deinit` in 424a25e. Everything else on this
list compiled as written. Left here as a record; nothing below needs chasing.

- ~~**`deinit` under strict concurrency**~~ in `Core/SessionClock.swift` and
  `Store/Entitlements.swift`. Swift 6 did reject both. Fixed with `isolated
  deinit` rather than by dropping the `deinit`, since both tasks run until
  cancelled.
- ~~**`SessionClock.start()`** and its redundant `MainActor.run`~~ — compiled.
- ~~**The switch expression** in `SessionEngine.finish(as:)`~~ — compiled.
- ~~**`Font.rounded(_:_:)` / `Font.plain(_:_:)`**~~ — compiled.
- **The StoreKit configuration path** in the shared scheme. Still unverified —
  nothing has run StoreKit yet. If Xcode says the configuration is missing,
  re-pick `Products.storekit` in Scheme ▸ Run ▸ Options ▸ StoreKit
  Configuration.
- **`GeometryProxy.reservedRegions`** in `Views/Outer/TimerFaceView.swift` is
  inside `#if DUO_SDK`, so it cannot break the build until you set the flag.

### 3. Run BUILD.md's end-of-day-1 test on the simulator

Arm one minute, lock, wait, unlock: **Kept — 1m**. Arm again, lock, unlock after
ten seconds, wait out the grace: **Broken**. `ShutTests` says both pass as code;
this is the run that says they pass as an app.

Then the same on the Duo simulator with the fold, if Milestone 0 said yes.

### 4. StoreKit in the simulator

Buy, restore, and each Pro gate: full history, week and month totals, labels on
the result screen, the Custom cell in the duration grid, the face picker, the
grace stepper. Then check the free tier still reads correctly — History titled
"Today", ring face only, grace fixed at 10s.

### 5. ~~Replace `Tools/logic-check/` with a test target~~ — done 2026-09-20

`ShutTests` is in the project and green. `SessionEngine` gained a clock seam to
make it testable; it had been reading `Date.now` directly, contrary to what this
file and `DEFERRED.md` both claimed.

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

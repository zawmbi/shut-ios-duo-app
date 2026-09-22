# Shut

Close the phone to start a focus block. Open it and the block dies.

An iOS app for iPhone Duo (Apple's foldable, ships Oct 23 2026). The hinge is the
commitment device: there is no allowlist to edit, no "just five more minutes"
button, no way to half-close a phone by accident. You either kept it shut or you
didn't.

---

## Non-negotiables

**No third-party dependencies.** SwiftUI, SwiftData, StoreKit 2, UserNotifications,
OSLog. Nothing else. No SPM packages, no analytics SDK, no crash reporter. If you
think we need a package, say so and stop — don't add one.

**No backend.** No accounts, no sign-in, no server, no network calls of any kind
except StoreKit's. The privacy nutrition label must read "Data Not Collected" in
every category, and that is a feature we advertise, not an accident.

**No dark patterns.** No countdown-timer paywalls, no fake urgency, no "are you
sure you want to leave" guilt screens, no streak-loss shaming beyond a plain
statement of fact. The app's entire premise is honesty about your own behaviour;
manipulating the user contradicts the product.

**Ship over polish.** This is a two-day build with a hard stop. When a decision is
between shipping a simpler version and building the better version, ship the
simpler one and note it in `DEFERRED.md`.

---

## Target and toolchain

**You need two Xcodes, and which one you reach for depends on what you're doing.**
`HANDOFF.md` carries the full table; the short version:

- **Develop on Xcode 27.1**, iOS 27.1 SDK. It is the only one with the Duo SDK
  and the Duo simulator. **It is a beta**, so nothing built with it can go to the
  App Store.
- **Archive on the Xcode 27.0 release.** Apple rejects App Store builds made with
  a beta Xcode. Building against Xcode 26 or earlier letterboxes the app away
  from the status bar and camera on Duo — don't do that either.
- Leave `xcode-select` on the release Xcode so an archive can't be cut with the
  beta by accident, and reach for the beta per command:
  `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun …`
- Deployment target: iOS 26.0. See "The universal-build rule" below for why it
  isn't 27.1.
- Single app target, no extensions in v1.
- Swift 6 language mode, strict concurrency. `SessionEngine` and `HingeMonitor`
  are `@MainActor`.
- Test device: the iPhone Duo simulator, opened through **Device Hub**
  (`Xcode-beta.app/Contents/Applications/DeviceHub.app` — there is no standalone
  Simulator.app in Xcode 27). Its poses are **closed / book (~100°) / open**,
  plus any position in 0.0–1.0. No physical hardware exists outside Apple until
  Oct 23, so every hinge behaviour is simulator-verified only. Write the code so
  a wrong assumption about real hardware is a one-file fix.

---

## The universal-build rule

**The App Store has no per-model availability switch.** `UIRequiredDeviceCapabilities`
filters by hardware capability from a fixed list (nfc, gyroscope, metal, arm64…)
and Apple never added a foldable key. App Review guideline 2.4.1 expects the app to
run on currently shipping devices, so an app that opens to a "requires iPhone Duo"
dead end is a rejection risk.

So: **one universal build, two experiences, branched at runtime.**

- On Duo, the hinge context is non-nil. Full product.
- On every other iPhone, it comes back `nil`. The app becomes a plain focus timer
  where *locking the screen* substitutes for *folding the phone*. Same engine, same
  data model, different trigger and different copy.

`HingeMonitor` is the only place in the codebase that knows which device it's on.
Nothing else branches on hardware — everything else consumes
`HingeMonitor.trigger`, which is either `.fold` or `.lock`. If you find yourself
writing a second `isDuo` check somewhere else, the abstraction is wrong.

---

## iPhone Duo APIs

Verified against the iOS 27.1 SDK on 2026-09-21. Transcript in `FINDINGS.md`.

| What | SwiftUI | UIKit |
|---|---|---|
| Hinge posture + angle | `.onHingeChange { oldContext, newContext in … }` | `UIHingeInteraction` |
| The fold / camera regions | `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | `UIView.reservedRegions(kind:options:)` |
| Two-pane adaptive container | `ArrangementView` with `.split` / `.overlay` | `UIArrangementViewController` |
| Is the toolbar vertical right now | `EnvironmentValues.toolbarVerticalEdge` | `UITraitCollection.verticalBarEdge` |

Notes that matter for this app:

- **`onHingeChange` hands back two contexts, old and new.** Use the new one.
- It **fires once on appear** with the posture the device is already in, so a
  phone that is already shut at launch reports correctly. No seed read.
- The hinge carries **both** a coarse `status` **and** a continuous `angle`
  (a SwiftUI `Angle`). We only need the status. Ignore the angle entirely —
  reading it invites precision bugs we can't test for.
- **`DeviceHinge.Status` is a struct, not an enum.** Its members are `.closed`,
  `.partiallyOpen` and `.fullyOpen`; there is no `.unknown` and no exhaustive
  switch. Compare with `==` and default to open, which never starts a block by
  accident.
- `context.hinge` is **nil on every non-Duo iPhone**. Always unwrap. This is the
  single most important line in the app. **But nil is not proof of a non-Duo**:
  Apple also delivers nil when the observer leaves a hierarchy that provides
  hinge updates, so it can arrive mid-session on a real Duo. `HingeMonitor`
  latches `isFoldable` on and treats a nil reading as "no new information",
  never as "downgrade this device".
- Reserved regions come in two kinds: `.division` (the fold) and `.occlusion`
  (the camera). A region can be active or inactive — the fold is active only when
  the phone is *partially* open. Query with `.includeInactive` when you need to
  make a structural layout decision that shouldn't thrash as the user folds.
- `UIScreen.main` is deprecated. Use scene bounds or
  `traitCollection.displayScale`.
- Never branch layout on `UIDevice.userInterfaceIdiom` or interface orientation.
  Use size classes. On the inner display both size classes are regular.
- Safe-area insets are asymmetric on Duo. Handle each edge independently; never
  assume left inset equals right inset.

### The outer display — answered, 2026-09-21

**There is no outer-display scene API, and none is needed.** iOS 27.1 has no
second `Scene`, no `WindowGroup` role, nothing. The system relocates the app's
single scene between the Duo's two integrated displays when the hinge crosses
the swap boundary. Measured from inside the running app while shut: one
connected scene, one `UIScreen`, 466×678pt on the cover display.

So **the app keeps executing when the phone is folded shut**, and what the cover
display shows is simply what the app draws. "Inner face vs outer face" is an
ordinary view-level branch on `HingeMonitor.posture` inside `RootView` — not a
scene-level decision. `Views/Outer/TimerFaceView` is presented like any other
view.

**Plan B is dead.** The local-notification fallback is not needed and should not
be written. `CameraCaptureAccessory` is moot.

Two things still unobserved, because poses can only be driven through Device
Hub's GUI: the `.division` (fold) region, which can only be non-empty while the
phone is *partially* open, and the swap transition itself. Do not write layout
that assumes a fold region exists until someone has seen one. On the cover
display both region kinds come back **empty** — the vertical status bar there
arrives as safe-area inset, not as a reserved region.

---

## Architecture

```
Shut/
  App/
    ShutApp.swift              scene setup and the model container
  Core/
    HingeMonitor.swift         the ONLY hardware-aware type
    SessionEngine.swift        state machine; owns all transitions
    SessionClock.swift         wall-clock elapsed time, suspension-safe
  Models/
    Session.swift              @Model
    Prefs.swift                @AppStorage wrapper
  Views/
    Inner/  Home, Interrupt, Result, History, Settings, Paywall
    Outer/  TimerFace          (a view, not a scene — RootView presents it)
    Shared/ RingProgress, DurationPicker, StatRow
  Store/
    Entitlements.swift         StoreKit 2, one non-consumable
```

### SessionEngine states

```
idle ──pick duration──▶ armed ──fold detected──▶ running
running ──unfold──▶ grace ──refold within N sec──▶ running
                     └──grace expires──▶ broken
running ──target reached──▶ complete (stays complete even if still folded)
```

**The grace period is load-bearing.** A hard fail on any unfold will earn
one-star reviews from people who opened their phone to check the time. Default
10 seconds, shown as a visible countdown on the inner display with a clear
"Break it" button for people who genuinely want to stop. Configurable in Pro.

### Timing

Never trust a `Timer` across app suspension. Store `startedAt: Date` and compute
elapsed by subtraction on every read. Use a `TimelineView` or `ContinuousClock`
for the UI tick only — it drives pixels, never state. If the engine and the clock
ever disagree, the engine's stored dates win.

### Data

One `@Model`:

```swift
@Model final class Session {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var targetSeconds: Int          // 0 == open-ended
    var outcomeRaw: String          // completed | broken | abandoned
    var interruptions: Int
    var label: String?              // Pro only
}
```

Day/week/month stats are computed, never stored. No migration plan needed in v1
because there is nothing to migrate from, but don't paint yourself into a corner:
additive-only changes to this model from here on.

---

## Free vs. Pro

One non-consumable, `xyz.zawmbi.shut.pro`, $4.99, StoreKit 2.

**Free, forever, genuinely useful:** unlimited sessions, any preset duration,
today's total, current streak, the outer-display timer face.

**Pro:** full history beyond today, week and month totals, session labels,
custom durations, alternate timer faces, adjustable grace period.

iCloud sync is **cut, not deferred.** SwiftData's CloudKit container is a
network call, and "nothing leaves your phone" is the product — both claims
cannot be on the same page. It was never promised in the paywall or the store
copy, so nothing user-facing changes. See `DEFERRED.md`.

The paywall appears in exactly two places: tapping History, and a single row in
Settings. It never interrupts a session, never appears on launch, and never
appears at the moment a user completes a block — that moment belongs to them.

---

## Voice

Plain, short, slightly dry. The app is a tool, not a coach. It never congratulates
and never scolds.

- Good: "42 minutes. Shut." / "Opened at 12:04. 18 minutes left." / "Broken."
- Bad: "Great job! 🎉 You crushed that focus session!"
- Bad: "You gave in. Try harder next time."

No emoji anywhere in the UI. System font, SF Rounded for the timer face only.

---

## Publishing

Zawmbi Productions LLC (Illinois file no. 18663899, active since 09-14-2026).
Ships under the existing App Store Connect account used for Attendize — no new
team setup required.

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

- Xcode 27.1 or later, iOS 27.1 SDK. Building against Xcode 26 or earlier
  letterboxes the app away from the status bar and camera on Duo — don't.
- Deployment target: iOS 26.0. See "The universal-build rule" below for why it
  isn't 27.1.
- Single app target, no extensions in v1.
- Swift 6 language mode, strict concurrency. `SessionEngine` and `HingeMonitor`
  are `@MainActor`.
- Test device: the iPhone Duo simulator in Xcode 27.1, which has pose controls for
  closed / tent / laptop / partially folded / fully open. No physical hardware
  exists outside Apple until Oct 23, so every hinge behaviour is simulator-verified
  only. Write the code so a wrong assumption about real hardware is a one-file fix.

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

Confirmed from Apple's *Preparing your app for iPhone Duo*:

| What | SwiftUI | UIKit |
|---|---|---|
| Hinge posture + angle | `.onHingeChange { context in … }` | `UIHingeInteraction` |
| The fold / camera regions | `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` | `UIView.reservedRegions(kind:options:)` |
| Two-pane adaptive container | `ArrangementView` with `.split` / `.overlay` | `UIArrangementViewController` |
| Is the toolbar vertical right now | `EnvironmentValues.toolbarVerticalEdge` | `UITraitCollection.verticalBarEdge` |

Notes that matter for this app:

- The hinge context carries **both** a coarse status (closed / partially open /
  fully open) **and** a continuous angle. We only need the coarse status. Ignore
  the angle entirely — reading it invites precision bugs we can't test for.
- `context.hinge` is **nil on every non-Duo iPhone**. Always unwrap. This is the
  single most important line in the app.
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

### ⚠️ APIs to verify before relying on them

I could not confirm exact symbol names for these. **Do not invent them.** Check
Apple's tech talk *Leverage multiple displays and scenes on iPhone Duo*
(developer.apple.com/videos/play/tech-talks/111464) and the current SDK headers,
then write down what you actually find in `FINDINGS.md`:

1. **How an app presents different content on the outer display vs. the inner one.**
   The entire product depends on this. It's a scene-level API, not a view modifier.
2. **Whether an app keeps executing when the phone is folded shut**, and in which
   scene. The outer display stays active when closed — it is not a laptop lid — so
   this probably works, but "probably" is not a foundation.
3. `CameraCaptureAccessory` — mentioned in the docs for showing content on the
   outer display during a capture session. Probably not what we want, but read it
   before ruling it out; it may reveal the general outer-display pattern.

If (1) and (2) don't pan out, take Plan B immediately: schedule a
`UNNotificationRequest` for the target time, detect the fold on the way down,
recompute everything from `startedAt` when the app comes back to the foreground,
and ship without a live outer-display face. Worse product, still shippable. Make
that call in the first hour, not on day two.

---

## Architecture

```
Shut/
  App/
    ShutApp.swift              scene setup, inner vs outer routing
  Core/
    HingeMonitor.swift         the ONLY hardware-aware type
    SessionEngine.swift        state machine; owns all transitions
    SessionClock.swift         wall-clock elapsed time, suspension-safe
  Models/
    Session.swift              @Model
    Prefs.swift                @AppStorage wrapper
  Views/
    Inner/  Home, Interrupt, Result, History, Settings, Paywall
    Outer/  TimerFace
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

# Deferred

Things deliberately cut from v1. Add to this list rather than expanding scope.

**Still owed, and why each one isn't done:**

- ~~**A test target.**~~ Done on 2026-09-20. `ShutTests` runs the same cases
  against the Swift, and the Python stand-in it replaced has been deleted. Note
  that `SessionEngine` did *not* take an injectable date as this file once
  claimed — it read `Date.now` directly in six places, and testing it at all
  meant giving it a clock seam. `Stats` really was injectable.
- ~~**Milestone 0.**~~ Answered 2026-09-21, and the fold was driven by hand in
  Device Hub on 2026-09-23. See `FINDINGS.md`.

- **Recording / screen-time integration.** Shut reports its own blocks only. No
  `DeviceActivity`, no `FamilyControls` — both need an entitlement request and
  neither survives a two-day build.
- **iCloud sync — cut.** Listed as Pro in `CLAUDE.md`, but never in
  `PaywallView.features` or the store copy, so there was no user-facing claim to
  keep. Cut rather than deferred: a CloudKit container is a network call, and the
  privacy claim is the more valuable half of the product.
- **Widgets and Live Activities.** A Live Activity is the obvious 1.1.
- ~~**Labels UI.**~~ **Built.** Pro names a block on the result screen and the
  name shows in History, so the paywall claim stands.
- **Onboarding.** `PrefKey.hasOnboarded` is defined and unused. The home screen
  explains itself; a first-run flow can wait.
- ~~**Custom durations.**~~ **Built.** A Custom cell in the duration grid opens
  an hours/minutes sheet for Pro; free taps it and gets the paywall.
- **Sound selection.** One sound, on or off.
- **Localisation.** English only.

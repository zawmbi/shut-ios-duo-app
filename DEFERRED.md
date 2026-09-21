# Deferred

Things deliberately cut from v1. Add to this list rather than expanding scope.

**Still owed, and why each one isn't done:**

- **A test target.** `Stats` and `SessionEngine` are pure and take an injectable
  date, which is what makes them testable — but there is no XCTest target,
  because adding one means editing the project on a Mac. The logic was verified
  another way in the meantime: `Tools/logic-check/` ports both types line for
  line and runs the day-boundary and state-machine cases, including BUILD.md's
  end-of-day-1 test. It is a stand-in, not a substitute — it proves the
  algorithm, never the Swift. Port it to XCTest and delete it.
- **Milestone 0.** Still entirely open; see `FINDINGS.md`. Nothing in this tree
  has been compiled.

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

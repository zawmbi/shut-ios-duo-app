# Deferred

Things deliberately cut from v1. Add to this list rather than expanding scope.

- **Recording / screen-time integration.** Shut reports its own blocks only. No
  `DeviceActivity`, no `FamilyControls` — both need an entitlement request and
  neither survives a two-day build.
- **iCloud sync.** Listed as a Pro feature in the paywall copy. Either build it
  (SwiftData CloudKit container, roughly an hour) or cut the line from
  `PaywallView.features` before submitting. Do not ship the claim without the
  feature.
- **Widgets and Live Activities.** A Live Activity is the obvious 1.1.
- **Labels UI.** The `Session.label` field exists and is unused. Pro paywall
  mentions it — same rule as iCloud: build it or cut the line.
- **Onboarding.** `PrefKey.hasOnboarded` is defined and unused. The home screen
  explains itself; a first-run flow can wait.
- **Custom durations.** Presets only in v1. Pro paywall mentions custom lengths —
  this one is ~20 minutes of work, so build it.
- **Sound selection.** One sound, on or off.
- **Localisation.** English only.

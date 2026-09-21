# Findings

Fill this in during Milestone 0. Everything below is an open question that the
source tree currently guesses at. Nothing else should be built until these are
answered.

> **Status: every question below is still open.** They need Xcode 27.1, the
> iPhone Duo simulator and the SDK headers — a Mac, in other words — and none of
> that was available to the work done so far. **Nothing in this tree has been
> through a compiler.** Treat it as unverified Swift until it builds once, and
> treat `Core/HingeBridge.swift` and the outer-display scene in
> `App/ShutApp.swift` as guesses until this file is filled in. `-D DUO_SDK` is
> deliberately **not** set in the Xcode project for that reason.

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

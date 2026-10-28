# Shut

Close the phone to start a focus block. Open it and the block dies.

iOS 26+, iPhone Duo-first. SwiftUI, SwiftData, StoreKit 2. No dependencies, no
backend, no analytics, no network calls except StoreKit's.

## Getting started

```
open Shut.xcodeproj
```

The project is committed. `Shut/` is a file-system-synchronized group, so a file
added to the tree joins the target without a project edit. The shared scheme
already points its StoreKit configuration at `Products.storekit`, so buy and
restore work in the simulator with no App Store Connect round trip — if Xcode
reports the configuration missing, re-pick it in Scheme ▸ Run ▸ Options ▸
StoreKit Configuration.

> **The Duo path has never run.** The app compiles and its logic is covered by
> `ShutTests`, but everything behind `-D DUO_SDK` is still unverified: it needs
> Xcode 27.1 and the iPhone Duo simulator, neither of which the tree has been
> near. See `FINDINGS.md`.

The app is meant to build and run on any iPhone as a lock-to-focus timer. The
iPhone Duo path is behind a compile flag:

**Build Settings ▸ Swift Compiler - Custom Flags ▸ Other Swift Flags ▸ `-D DUO_SDK`**

Do not set that flag until `FINDINGS.md` is filled in. Two files guess at
unverified APIs and are marked with VERIFY banners:

- `Core/HingeBridge.swift` — the hinge observer
- `App/ShutApp.swift` — the outer-display scene

Everything else is ordinary SwiftUI and should compile as written.

## Shape of it

```
Models/Session.swift        one @Model, additive changes only
Core/HingeMonitor.swift     the only hardware-aware type
Core/HingeBridge.swift      ⚠️ unverified Duo APIs, isolated here on purpose
Core/SessionEngine.swift    the state machine; all transitions live here
Core/SessionClock.swift     drives pixels, never state
Core/Stats.swift            totals and streaks, always computed
Store/Entitlements.swift    one non-consumable
Views/Inner/                home, interrupt, result, history, paywall, settings
Views/Outer/                the timer face
```

## Rules that matter

**Never trust a timer across suspension.** Every value is derived by subtracting
stored `Date`s. `SessionClock` exists only so SwiftUI has something to observe;
if the engine and the clock disagree, the engine wins.

**One binary, two experiences.** `HingeMonitor` is the only place that knows what
device it is on. Everything downstream reads `trigger` (`.fold` or `.lock`) and
`posture`. A second `isFoldable` check anywhere else means the abstraction is
wrong — widen it instead.

**The grace period is load-bearing.** A hard fail on any unfold earns one-star
reviews from people who opened their phone to check the time. Ten seconds,
visible countdown, explicit "Break it" button.

**No dark patterns.** No countdown paywalls, no guilt screens, no streak shaming
past a plain statement of fact. The app's premise is honesty about your own
behaviour.

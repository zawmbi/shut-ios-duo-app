# Shut — build plan

Two days, hard stop. The source tree is written; this is the order to work it in
and what has to be true before you submit.

---

## Status

Work done so far was done **without a Mac**: nothing in the tree has been
compiled or run on a simulator, and every question in `FINDINGS.md` is still
open. Milestone 0 is unchanged and still first.

Done:

- The source tree, plus an Xcode project — single app target, iOS 26.0, Swift 6,
  `Shut/` as a file-system-synchronized group, shared scheme wired to
  `Products.storekit`. Structurally validated, never opened in Xcode.
- **Day 2, hour 4.** Every paywall claim now matches the binary. Custom lengths,
  week and month totals, labels and the face picker were built; iCloud sync was
  cut. Four of the six claims had nothing behind them, including two this plan
  did not flag: the face picker did not exist, and the grace-period stepper in
  Settings never reached the engine.
- **Day 2, hour 5.** The accessibility pass — VoiceOver labels, Dynamic Type,
  reduce-motion.
- Three engine bugs. The worst recorded a finished block as *Broken* when the
  user opened the phone.
- **Day 1, hour 7's** streak check across a midnight boundary, run against
  `Tools/logic-check/` rather than a simulator.

Still needs a Mac, in this order:

1. **Milestone 0.** Unchanged, and still the first hour.
2. First clean build on the plain-iPhone path, `DUO_SDK` off.
3. StoreKit in the simulator: buy, restore, and each Pro gate.
4. An XCTest target to replace `Tools/logic-check/`.
5. App icon, screenshots, metadata, archive, submit.

---

## Milestone 0 — the spike (first hour, before anything else)

**Do not skip this and do not do it second.** Two files in the tree guess at
APIs I could not verify, and the entire product rests on them. If the guesses are
wrong, you want to know before you've built UI on top.

1. Open the iPhone Duo simulator in Xcode 27.1.
2. New blank SwiftUI app. Attach `.onHingeChange` and print whatever it hands
   back. Rotate through every pose.
3. Answer the four questions in `FINDINGS.md`.
4. Find out whether the app keeps running when folded, and what the outer display
   shows. This is question 2 and it's the one that decides the product.
5. Port the corrections into `Core/HingeBridge.swift` and `App/ShutApp.swift`,
   then set `-D DUO_SDK` in Other Swift Flags.

**If the outer-display scene doesn't exist or doesn't work:** take Plan B
immediately — single window, local notification at the target time, recompute
from `startedAt` on foreground. The engine already works that way, so Plan B is
a deletion rather than a rewrite. Make that call in the first hour and write it
down. Do not spend day two discovering it.

---

## Day 1

| | |
|---|---|
| **Hour 1** | Milestone 0 above. |
| **Hours 2–3** | Xcode project, add `Shut/` as sources, first clean build on the plain-iPhone path (no `DUO_SDK`). Confirm lock-to-focus works end to end: pick 25m, lock, wait, unlock, see the result. This path must work regardless of what Milestone 0 found — it's what ships to every non-Duo iPhone. |
| **Hours 4–5** | Wire the Duo path. Fold to start, open to interrupt, grace countdown, refold to continue. Every pose, every transition. |
| **Hour 6** | The outer timer face. This is the screenshot the whole launch rests on — spend real time on it. |
| **Hour 7** | SwiftData persistence, today's total, streak. Verify the streak maths across a midnight boundary by faking dates. |

**End of day 1 test:** arm a 1-minute block, fold, wait, open. You should get
"Kept — 1m". Then arm another, fold, open after 10 seconds, wait out the grace,
and get "Broken". If both work, the app is real.

## Day 2

| | |
|---|---|
| **Hours 1–2** | StoreKit. Add `Products.storekit` as the scheme's StoreKit configuration, test buy and restore in the simulator. |
| **Hour 3** | History, paywall, settings. |
| **Hour 4** | Cut or build the three claims in `DEFERRED.md` that the paywall currently makes and the app doesn't keep: iCloud sync, labels, custom durations. Custom durations is ~20 minutes — build it. The other two, cut the line. **Do not ship a paywall that promises something the binary doesn't do.** |
| **Hour 5** | Accessibility pass. VoiceOver through every screen, Dynamic Type at XXL, reduce-motion. The timer face needs an accessibility label that reads remaining time, since the digits are decorative to VoiceOver as written. |
| **Hour 6** | App icon, screenshots, metadata, archive, submit. |

---

## Before you submit

- [ ] Runs correctly on a non-folding iPhone with `DUO_SDK` **off**. Review will
      test on a regular device. Guideline 2.4.1.
- [ ] Nothing in the UI says "requires iPhone Duo" as a wall. The reduced
      experience is a real product, not an error state.
- [ ] Privacy nutrition label: **Data Not Collected**, every category. Verify
      nothing sneaks a network call in — there should be zero `URLSession` in the
      tree.
- [ ] Notification permission is requested at a sensible moment and the app works
      if it's denied.
- [ ] Every paywall claim is true.
- [ ] Tested with the phone folded through a full block without touching it.

---

## App Store metadata

**Name** (30 max) — `Shut: Fold to Focus` · 19

**Subtitle** (30 max) — `Close the phone. Begin focus.` · 28

**Keywords** (100 max) —
`focus,deep work,pomodoro,timer,screen time,foldable,fold,duo,distraction,study,attention,detox` · 94

**Promotional text** (170 max)
> Built for iPhone Duo. Fold the phone and a focus block starts on the outer
> display. Open it and the block dies. No allowlist to edit, no five-more-minutes
> button.

**Description**

> Shut is a focus timer with one input: the hinge.
>
> Fold your iPhone Duo and a block begins. The timer runs on the outer display
> where you can see it without opening anything. Open the phone before the block
> is up and it breaks — you get ten seconds to fold it back before that counts.
>
> Every other focus app asks you to configure a blocklist and then trust yourself
> not to edit it. This one doesn't, because you can't half-close a phone by
> accident. The commitment is physical.
>
> On iPhones that don't fold, locking the screen does the same job.
>
> — Unlimited blocks, free, forever
> — Today's total and your current streak
> — Nothing is collected and nothing is sent anywhere. No account, no server, no
>   analytics. Your blocks never leave the phone.
>
> Shut Pro, one payment: full history, weekly and monthly totals, labels, custom
> lengths, extra timer faces, and an adjustable grace period.

**Category** — Productivity (primary), Health & Fitness (secondary)
**Age** — 4+
**Price** — Free, with `xyz.zawmbi.shut.pro` at $4.99 non-consumable

**Screenshots** — six, and the fold has to be visible in at least three:

1. The phone folded shut, outer display showing 18:42 left. The hero.
2. Home screen, "Fold to begin" in green.
3. The interrupt screen mid-grace: "You opened it. 9."
4. Result: "Kept — 45m".
5. History.
6. A plain-text card: "Nothing leaves your phone."

---

## Launch positioning

The device ships **Oct 23**; pre-orders open **Oct 16**. Being live before either
date is the whole point — Apple builds launch collections from apps that already
exist.

File a **featuring nomination** in App Store Connect the day it goes live, not
later. The pitch is one sentence: this app is impossible on a phone that doesn't
fold. That's a stronger claim than almost anything else that will be in the queue,
and it's the reason to have built this one first.

For Zawmbi's channels, the demo is fifteen seconds and needs no face: a phone
closing, a timer starting on the outer display, a hand opening it, the streak
dying. Shoot it once the simulator works — you don't need hardware to make the
first one.

---

## Honest expectations

The Duo installed base will be small for a year at $1,999. Realistic outcome here
is thousands of downloads, not hundreds of thousands, and a conversion rate in the
low single digits on a $4.99 unlock. The case for building it isn't the revenue —
it's that the featuring lottery is winnable when almost nothing else in the store
uses the hinge, and the same two days spent on a fourth freelance site wouldn't buy
a lottery ticket at all.

# logic-check

A stand-in for the test target this project does not have yet.

`Stats` and `SessionEngine` are pure and take an injectable date, which is what
makes them testable — but adding an XCTest target means editing the Xcode project
on a Mac, and the work that produced these files had no Mac. So both types were
ported line for line into Python and the interesting cases run there:

```
python3 Tools/logic-check/stats_check.py     # day boundaries, streaks, totals
python3 Tools/logic-check/engine_check.py    # the state machine
```

`engine_check.py` runs BUILD.md's end-of-day-1 test — arm a minute, fold, wait,
open, expect *Kept — 1m*; then open early, wait out the grace, expect *Broken* —
along with the bug that test would have caught: a block whose target elapsed
while the phone was shut used to be recorded as *Broken*.

**This proves the algorithm, never the Swift.** It cannot catch a compile error,
a SwiftUI mistake, a SwiftData or StoreKit problem, or the two unverified Duo
APIs. It will also drift from the Swift the moment someone edits one and not the
other.

Port these cases to XCTest on the first Mac that opens the project, then delete
this directory.

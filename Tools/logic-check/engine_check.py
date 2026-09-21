"""Faithful port of the patched SessionEngine + HingeMonitor, on a fake clock.

Runs BUILD.md's end-of-day-1 test and the sequences around it. Nothing ticks
while the phone is shut, exactly as on device: the process is suspended, so the
harness only ticks while the app is 'awake'.
"""
class Engine:
    def __init__(self, grace=10):
        self.now = 0.0
        self.phase = "idle"; self.startedAt = None; self.graceEndsAt = None
        self.releasedAt = None; self.interruptions = 0
        self.targetSeconds = 0; self.graceSeconds = grace
        self.lastPosture = "open"; self.saved = []

    # derived
    @property
    def elapsed(self): return 0 if self.startedAt is None else max(0, self.now - self.startedAt)
    @property
    def graceRemaining(self): return 0 if self.graceEndsAt is None else max(0, self.graceEndsAt - self.now)

    # intents
    def arm(self, target):
        self.targetSeconds = target
        self.startedAt = self.graceEndsAt = self.releasedAt = None
        self.interruptions = 0; self.phase = "armed"
    def breakNow(self):
        if self.phase in ("running", "grace"): self.finish("abandoned")
    def acknowledge(self):
        self.phase = "idle"; self.startedAt = self.graceEndsAt = self.releasedAt = None

    # inputs
    def handle(self, posture):
        if posture == self.lastPosture: return
        self.tick()                                  # <- the fix
        committed = posture == "closed"
        if self.phase == "armed" and committed:
            self.startedAt = self.now; self.phase = "running"
        elif self.phase == "running" and not committed:
            self.interruptions += 1
            self.releasedAt = self.now
            self.graceEndsAt = self.now + self.graceSeconds
            self.phase = "grace"
        elif self.phase == "grace" and committed:
            self.graceEndsAt = None; self.releasedAt = None; self.phase = "running"
        self.lastPosture = posture

    def tick(self):
        if self.phase == "running":
            if self.targetSeconds > 0 and self.elapsed >= self.targetSeconds:
                self.finish("completed")
        elif self.phase == "grace":
            if self.graceRemaining <= 0:
                self.finish("broken")

    def finish(self, outcome):
        if self.startedAt is None:
            self.phase = "idle"; return
        if outcome == "completed":
            ended = self.startedAt + self.targetSeconds if self.targetSeconds > 0 else self.now
        else:
            ended = self.releasedAt if self.releasedAt is not None else self.now
        self.saved.append({"outcome": outcome, "elapsed": ended - self.startedAt,
                           "interruptions": self.interruptions})
        self.phase = "complete" if outcome == "completed" else "broken"
        self.startedAt = self.graceEndsAt = self.releasedAt = None

    # harness
    def awake_until(self, t):
        """Tick 4x/second up to t, the way SessionClock drives the app."""
        while self.now < t:
            self.now = min(t, self.now + 0.25); self.tick()
    def shut_until(self, t):
        """Time passes with no ticks at all — the process is suspended."""
        self.now = t

def scene(monitor_foldable, phase):
    """HingeMonitor.ingestScenePhase, post-fix."""
    if monitor_foldable: return None
    return {"active": "open", "background": "closed", "inactive": None}[phase]

fails = []
def check(name, got, want):
    ok = got == want
    if not ok: fails.append(name)
    print(f"  {'PASS' if ok else 'FAIL'}  {name}: got {got!r}, want {want!r}")

print("BUILD.md end-of-day-1 test")
e = Engine(); e.arm(60)
e.handle("closed")                      # fold
e.shut_until(61)                        # a minute passes, phone shut, nothing ticks
e.handle("open")                        # open it
check("1-minute block, folded through: Kept 1m",
      (e.phase, e.saved[-1]["outcome"], f"{round(e.saved[-1]['elapsed'])//60}m"),
      ("complete", "completed", "1m"))

e = Engine(); e.arm(60)
e.handle("closed")
e.shut_until(10); e.handle("open")      # opened after 10s
e.awake_until(21)                       # wait out the 10s grace
check("opened early, grace expires: Broken",
      (e.phase, e.saved[-1]["outcome"]), ("broken", "broken"))
check("... and it ended when they opened it, not when grace ran out",
      e.saved[-1]["elapsed"], 10)

print("\nthe bug this fixes")
e = Engine(); e.arm(25 * 60)
e.handle("closed"); e.shut_until(3 * 3600)   # finished, then left shut for hours
e.handle("open")
check("block finished hours ago, opened now: Kept, not Broken",
      (e.phase, e.saved[-1]["outcome"]), ("complete", "completed"))
check("... credited its target, not the three hours",
      e.saved[-1]["elapsed"], 25 * 60)
check("... and not counted as an interruption", e.saved[-1]["interruptions"], 0)

e = Engine(); e.arm(60)
e.handle("closed"); e.shut_until(60.0)       # opened at the exact target second
e.handle("open")
check("opened at the exact target second: Kept",
      e.saved[-1]["outcome"], "completed")

e = Engine(); e.arm(60)
e.handle("closed"); e.shut_until(59.5)
e.handle("open"); e.awake_until(70)
check("opened half a second early: Broken", e.saved[-1]["outcome"], "broken")

print("\ngrace period")
e = Engine(); e.arm(60)
e.handle("closed"); e.shut_until(10)
e.handle("open"); e.awake_until(15)
e.handle("closed")                      # refold inside the grace window
e.shut_until(61); e.handle("open")
check("refold inside grace: Kept", e.saved[-1]["outcome"], "completed")
check("... one interruption recorded", e.saved[-1]["interruptions"], 1)
check("... credited the full target", e.saved[-1]["elapsed"], 60)

e = Engine(grace=30); e.arm(60)          # Pro's adjustable grace
e.handle("closed"); e.shut_until(10); e.handle("open")
e.awake_until(35)
check("30s grace still running at 25s", e.phase, "grace")
e.awake_until(41)
check("30s grace expired at 31s", e.phase, "broken")

e = Engine(); e.arm(60)
e.handle("closed"); e.shut_until(10); e.handle("open")
e.breakNow()
check("Break it: Stopped, not Broken", e.saved[-1]["outcome"], "abandoned")

print("\nopen-ended block")
e = Engine(); e.arm(0)
e.handle("closed"); e.shut_until(1800)
e.handle("open"); e.awake_until(1811)
check("open-ended never self-completes, breaks on open", e.saved[-1]["outcome"], "broken")
check("... elapsed is the time it was shut", e.saved[-1]["elapsed"], 1800)

print("\nchatty sensor and pose noise")
e = Engine(); e.arm(60)
for _ in range(5): e.handle("closed")
e.shut_until(10)
for _ in range(5): e.handle("open")
check("repeated identical postures: one interruption", e.interruptions, 1)

e = Engine(); e.arm(60)
e.handle("closed"); e.shut_until(10)
e.handle("partial")                     # partially open is not committed
check("partially open releases the block", e.phase, "grace")
e.handle("closed")
check("... and folding back resumes it", e.phase, "running")

print("\nlock path: scene phase")
check("Control Centre (.inactive) is ignored", scene(False, "inactive"), None)
check("locking the screen (.background) commits", scene(False, "background"), "closed")
check("returning (.active) releases", scene(False, "active"), "open")
check("on a foldable, scene phase is ignored entirely", scene(True, "background"), None)

e = Engine(); e.arm(60)
p = scene(False, "inactive")            # armed, user pulls Control Centre
if p: e.handle(p)
check("Control Centre does not start an armed block", e.phase, "armed")
e.handle("closed"); e.shut_until(5)
p = scene(False, "inactive")            # running, notification banner
if p: e.handle(p)
check("... and does not break a running one", e.phase, "running")

print("\n" + ("ALL PASS" if not fails else f"{len(fails)} FAILED: {fails}"))

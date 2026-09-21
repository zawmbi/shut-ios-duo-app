"""Faithful port of Shut/Core/Stats.swift, to exercise the day-boundary logic.

Day arithmetic uses `date` objects, which is what Calendar.startOfDay /
date(byAdding: .day:) do in Swift (calendar days, not 86400-second jumps), so
the DST behaviour matches.
"""
from datetime import datetime, timedelta, date

class S:                                    # a Session
    def __init__(self, started, minutes, outcome="completed"):
        self.startedAt = started
        self.endedAt = started + timedelta(minutes=minutes)
        self.outcome = outcome
    @property
    def counts(self): return self.outcome == "completed"
    @property
    def elapsed(self): return (self.endedAt - self.startedAt).total_seconds()

def today_total(sessions, now):
    return sum(s.elapsed for s in sessions if s.counts and s.startedAt.date() == now.date())

def streak(sessions, now):
    days = {s.startedAt.date() for s in sessions if s.counts}
    if not days: return 0
    cursor = now.date()
    if cursor not in days:
        y = cursor - timedelta(days=1)
        if y not in days: return 0
        cursor = y
    count = 0
    while cursor in days:
        count += 1
        cursor = cursor - timedelta(days=1)
    return count

def daily(sessions, days, now):
    today = now.date()
    out = []
    for off in reversed(range(days)):
        d = today - timedelta(days=off)
        out.append((d, sum(s.elapsed for s in sessions if s.counts and s.startedAt.date() == d)))
    return out

def fmt(sec):
    t = round(sec); h, m = t // 3600, (t % 3600) // 60
    return f"{h}h {m}m" if h else (f"{m}m" if m else f"{t}s")

def spoken(sec):
    t = max(0, round(sec)); h, m, s = t//3600, (t%3600)//60, t%60
    p = []
    if h: p.append(f"{h} hour{'' if h==1 else 's'}")
    if m: p.append(f"{m} minute{'' if m==1 else 's'}")
    if not p: p.append(f"{s} second{'' if s==1 else 's'}")
    return " ".join(p)

D = lambda y,mo,d,h=12,mi=0: datetime(y,mo,d,h,mi)
fails = []
def check(name, got, want):
    ok = got == want
    if not ok: fails.append(name)
    print(f"  {'PASS' if ok else 'FAIL'}  {name}: got {got!r}, want {want!r}")

print("streak")
now = D(2026,9,21)
check("three consecutive days ending today",
      streak([S(D(2026,9,21),25), S(D(2026,9,20),25), S(D(2026,9,19),25)], now), 3)
check("kept yesterday, nothing yet today (alive)",
      streak([S(D(2026,9,20),25)], now), 1)
check("last kept two days ago (dead)",
      streak([S(D(2026,9,19),25)], now), 0)
check("gap in the middle stops the count",
      streak([S(D(2026,9,21),25), S(D(2026,9,19),25)], now), 1)
check("broken blocks never count",
      streak([S(D(2026,9,21),25,"broken"), S(D(2026,9,20),25,"abandoned")], now), 0)
check("no sessions", streak([], now), 0)
check("several blocks in one day count once",
      streak([S(D(2026,9,21),25), S(D(2026,9,21,18),25), S(D(2026,9,20),25)], now), 2)

print("\nthe midnight boundary")
check("block started 23:50 and finished after midnight belongs to the day it started",
      streak([S(D(2026,9,20,23,50),25), S(D(2026,9,21),25)], now), 2)
check("... and its time lands on the start day, not today",
      today_total([S(D(2026,9,20,23,50),25)], now), 0)
check("a block running at the moment we ask still counts today",
      fmt(today_total([S(D(2026,9,21,11,40),25)], now)), "25m")
check("streak checked at 00:01 with yesterday's block is alive",
      streak([S(D(2026,9,20),25)], D(2026,9,21,0,1)), 1)
check("streak checked at 23:59 today",
      streak([S(D(2026,9,21),25)], D(2026,9,21,23,59)), 1)

print("\nmonth and DST boundaries (calendar-day arithmetic)")
check("streak across the end of a month",
      streak([S(D(2026,9,1),25), S(D(2026,8,31),25), S(D(2026,8,30),25)], D(2026,9,1)), 3)
check("streak across the end of a leap February",
      streak([S(D(2028,3,1),25), S(D(2028,2,29),25), S(D(2028,2,28),25)], D(2028,3,1)), 3)
check("streak across US spring-forward (23-hour day)",
      streak([S(D(2027,3,15),25), S(D(2027,3,14),25), S(D(2027,3,13),25)], D(2027,3,15)), 3)
check("streak across US fall-back (25-hour day)",
      streak([S(D(2026,11,2),25), S(D(2026,11,1),25), S(D(2026,10,31),25)], D(2026,11,2)), 3)

print("\nseven-day strip")
d = daily([S(D(2026,9,21),30), S(D(2026,9,18),60), S(D(2026,9,15),10)], 7, now)
check("oldest first, seven entries", [x[0].day for x in d], [15,16,17,18,19,20,21])
check("gaps present and zero", [fmt(x[1]) for x in d],
      ["10m","0s","0s","1h 0m","0s","0s","30m"])
check("a block outside the window is excluded",
      fmt(daily([S(D(2026,9,10),30)], 7, now)[0][1]), "0s")

print("\nspoken form for VoiceOver")
for sec, want in [(0,"0 seconds"), (1,"1 second"), (45,"45 seconds"), (60,"1 minute"),
                  (1500,"25 minutes"), (3600,"1 hour"), (5400,"1 hour 30 minutes"),
                  (7260,"2 hours 1 minute")]:
    check(f"spoken({sec})", spoken(sec), want)

print("\n" + ("ALL PASS" if not fails else f"{len(fails)} FAILED: {fails}"))

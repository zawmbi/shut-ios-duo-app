import Foundation
import Testing

@testable import Shut

/// Day-boundary arithmetic.
///
/// Ported from `Tools/logic-check/stats_check.py`, case for case.
///
/// Every date here is built through `Calendar.current`, because that is what
/// `Stats` reads. That makes the cases correct in any time zone, but it also
/// means the two DST cases below only cross a real transition when the machine
/// running them observes US daylight saving. Everywhere else they still prove
/// what matters — that the streak steps by calendar days rather than by
/// 86,400-second jumps — they just do it on days that all happen to be 24 hours
/// long. `Stats` takes its calendar from the environment and cannot be handed
/// a fixed one; giving it that seam is the only way to make these deterministic,
/// and it was not worth a production change for two cases.
@MainActor
struct StatsTests {

    // MARK: - Fixtures

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        let components = DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)
        guard let date = Calendar.current.date(from: components) else {
            fatalError("\(y)-\(mo)-\(d) \(h):\(mi) is not a date in the current calendar")
        }
        return date
    }

    private func session(
        _ start: Date,
        minutes: Int,
        _ outcome: SessionOutcome = .completed
    ) -> Session {
        let session = Session(startedAt: start, targetSeconds: minutes * 60)
        session.endedAt = start.addingTimeInterval(Double(minutes) * 60)
        session.outcome = outcome
        return session
    }

    // MARK: - Streak

    @Test("Three consecutive days ending today")
    func threeConsecutiveDays() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 25),
            session(date(2026, 9, 20), minutes: 25),
            session(date(2026, 9, 19), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: now) == 3)
    }

    @Test("Kept yesterday, nothing yet today: the streak is alive")
    func yesterdayOnlyIsAlive() {
        let now = date(2026, 9, 21)
        #expect(Stats.streak([session(date(2026, 9, 20), minutes: 25)], now: now) == 1)
    }

    @Test("Last kept two days ago: the streak is dead")
    func twoDaysAgoIsDead() {
        let now = date(2026, 9, 21)
        #expect(Stats.streak([session(date(2026, 9, 19), minutes: 25)], now: now) == 0)
    }

    @Test("A gap in the middle stops the count")
    func gapStopsTheCount() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 25),
            session(date(2026, 9, 19), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: now) == 1)
    }

    @Test("Broken and abandoned blocks never count")
    func brokenBlocksNeverCount() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 25, .broken),
            session(date(2026, 9, 20), minutes: 25, .abandoned),
        ]
        #expect(Stats.streak(sessions, now: now) == 0)
    }

    @Test("No sessions at all")
    func noSessions() {
        #expect(Stats.streak([], now: date(2026, 9, 21)) == 0)
    }

    @Test("Several blocks in one day count once")
    func severalBlocksInADayCountOnce() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 25),
            session(date(2026, 9, 21, 18), minutes: 25),
            session(date(2026, 9, 20), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: now) == 2)
    }

    // MARK: - The midnight boundary

    @Test("A block that runs past midnight belongs to the day it started")
    func blockAcrossMidnightBelongsToStartDay() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 20, 23, 50), minutes: 25),
            session(date(2026, 9, 21), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: now) == 2)
    }

    @Test("... and its time lands on the start day, not on today")
    func blockAcrossMidnightCountsOnStartDay() {
        let now = date(2026, 9, 21)
        let sessions = [session(date(2026, 9, 20, 23, 50), minutes: 25)]
        #expect(Stats.todayTotal(sessions, now: now) == 0)
    }

    @Test("A block running at the moment we ask still counts toward today")
    func blockRunningNowCountsToday() {
        let now = date(2026, 9, 21)
        let sessions = [session(date(2026, 9, 21, 11, 40), minutes: 25)]
        #expect(Stats.format(Stats.todayTotal(sessions, now: now)) == "25m")
    }

    @Test("Checked at 00:01, yesterday's block keeps the streak alive")
    func streakJustAfterMidnight() {
        let sessions = [session(date(2026, 9, 20), minutes: 25)]
        #expect(Stats.streak(sessions, now: date(2026, 9, 21, 0, 1)) == 1)
    }

    @Test("Checked at 23:59, today's block still counts")
    func streakJustBeforeMidnight() {
        let sessions = [session(date(2026, 9, 21), minutes: 25)]
        #expect(Stats.streak(sessions, now: date(2026, 9, 21, 23, 59)) == 1)
    }

    // MARK: - Month and DST boundaries

    @Test("A streak across the end of a month")
    func streakAcrossMonthEnd() {
        let sessions = [
            session(date(2026, 9, 1), minutes: 25),
            session(date(2026, 8, 31), minutes: 25),
            session(date(2026, 8, 30), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: date(2026, 9, 1)) == 3)
    }

    @Test("A streak across the end of a leap February")
    func streakAcrossLeapFebruary() {
        let sessions = [
            session(date(2028, 3, 1), minutes: 25),
            session(date(2028, 2, 29), minutes: 25),
            session(date(2028, 2, 28), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: date(2028, 3, 1)) == 3)
    }

    @Test("A streak across a 23-hour spring-forward day")
    func streakAcrossSpringForward() {
        let sessions = [
            session(date(2027, 3, 15), minutes: 25),
            session(date(2027, 3, 14), minutes: 25),
            session(date(2027, 3, 13), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: date(2027, 3, 15)) == 3)
    }

    @Test("A streak across a 25-hour fall-back day")
    func streakAcrossFallBack() {
        let sessions = [
            session(date(2026, 11, 2), minutes: 25),
            session(date(2026, 11, 1), minutes: 25),
            session(date(2026, 10, 31), minutes: 25),
        ]
        #expect(Stats.streak(sessions, now: date(2026, 11, 2)) == 3)
    }

    // MARK: - The seven-day strip

    @Test("Seven entries, oldest first")
    func stripIsSevenDaysOldestFirst() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 30),
            session(date(2026, 9, 18), minutes: 60),
            session(date(2026, 9, 15), minutes: 10),
        ]
        let strip = Stats.daily(sessions, days: 7, now: now)
        let days = strip.map { Calendar.current.component(.day, from: $0.day) }
        #expect(days == [15, 16, 17, 18, 19, 20, 21])
    }

    @Test("Gaps are present and zero")
    func stripKeepsGaps() {
        let now = date(2026, 9, 21)
        let sessions = [
            session(date(2026, 9, 21), minutes: 30),
            session(date(2026, 9, 18), minutes: 60),
            session(date(2026, 9, 15), minutes: 10),
        ]
        let strip = Stats.daily(sessions, days: 7, now: now).map { Stats.format($0.total) }
        #expect(strip == ["10m", "0s", "0s", "1h 0m", "0s", "0s", "30m"])
    }

    @Test("A block outside the window is excluded")
    func stripExcludesOlderBlocks() {
        let now = date(2026, 9, 21)
        let sessions = [session(date(2026, 9, 10), minutes: 30)]
        let strip = Stats.daily(sessions, days: 7, now: now)
        #expect(Stats.format(strip[0].total) == "0s")
    }

    // MARK: - Spoken form for VoiceOver

    @Test(
        "Spoken form, which a screen reader has to pronounce",
        arguments: [
            (seconds: TimeInterval(0), want: "0 seconds"),
            (seconds: TimeInterval(1), want: "1 second"),
            (seconds: TimeInterval(45), want: "45 seconds"),
            (seconds: TimeInterval(60), want: "1 minute"),
            (seconds: TimeInterval(1500), want: "25 minutes"),
            (seconds: TimeInterval(3600), want: "1 hour"),
            (seconds: TimeInterval(5400), want: "1 hour 30 minutes"),
            (seconds: TimeInterval(7260), want: "2 hours 1 minute"),
        ]
    )
    func spokenForm(_ c: (seconds: TimeInterval, want: String)) {
        #expect(Stats.spoken(c.seconds) == c.want)
    }

    // MARK: - Forgiveness

    /// Kept blocks on each of the given September 2026 days.
    private func kept(_ days: [Int]) -> [Session] {
        days.map { session(date(2026, 9, $0), minutes: 25) }
    }

    @Test("Free: the first missed day ever is forgiven")
    func freeForgivesFirstMiss() {
        // Kept 17, 18, missed 19, kept 20, 21.
        let sessions = kept([17, 18, 20, 21])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .none) == 2)
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .firstMiss) == 4)
    }

    @Test("Free: only the first — a later miss resets it")
    func freeDoesNotForgiveSecondMiss() {
        // Missed 12 (the first, forgiven) and 19 (not forgiven).
        let sessions = kept([10, 11, 13, 14, 15, 16, 17, 18, 20, 21])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .firstMiss) == 2)
    }

    @Test("Free: two missed days in a row are not bridged")
    func freeDoesNotBridgeTwoDays() {
        let sessions = kept([17, 18, 21])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .firstMiss) == 1)
    }

    @Test("Pro: one missed day in every seven is forgiven")
    func proForgivesWeekly() {
        // Missed 12 and 19: a week apart, both forgiven.
        let sessions = kept([10, 11, 13, 14, 15, 16, 17, 18, 20, 21])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .weekly) == 10)
    }

    @Test("Pro: two misses inside a week — the second resets it")
    func proDoesNotForgiveTwiceInAWeek() {
        // Missed 16 and 19: three days apart.
        let sessions = kept([14, 15, 17, 18, 20, 21])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .weekly) == 4)
    }

    @Test("A forgiven yesterday keeps the streak alive before today's block")
    func forgivenYesterdayKeepsItAlive() {
        let sessions = kept([18, 19])
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .firstMiss) == 2)
        #expect(Stats.streak(sessions, now: date(2026, 9, 21), forgiveness: .none) == 0)
    }
}

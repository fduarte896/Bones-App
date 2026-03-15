import Foundation
import Testing
@testable import Bones

@Suite(.tags(.scheduling))
struct MedicationSchedulingTests {

    // MARK: - addInterval

    @Test(arguments: [
        (IntervalUnit.hours, 8, 8),
        (IntervalUnit.days, 3, 72),
        (IntervalUnit.weeks, 2, 336),
    ])
    func addInterval_producesExpectedHourOffset(unit: IntervalUnit, value: Int, expectedHours: Int) {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let result = MedicationScheduling.addInterval(value, unit: unit, to: start)
        let diff = result.timeIntervalSince(start) / 3600
        #expect(Int(diff) == expectedHours)
    }

    @Test func addInterval_months_crossesBoundary() {
        let start = makeDate(year: 2026, month: 1, day: 31, hour: 10)
        let result = MedicationScheduling.addInterval(1, unit: .months, to: start)
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: result)
        #expect(month == 2, "Adding 1 month to Jan 31 should land in February")
    }

    // MARK: - preview (interval mode)

    @Test func preview_intervalHours() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start, mode: .interval, intervalValue: 8,
            intervalUnit: .hours, durationDays: 1, timesPerDay: 3
        )
        #expect(dates.count == 4)
        #expect(dates.first == start)
    }

    @Test func preview_intervalDays_multiDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start, mode: .interval, intervalValue: 1,
            intervalUnit: .days, durationDays: 3, timesPerDay: 1
        )
        #expect(dates.count == 4, "3-day duration with 1-day intervals: day 0, 1, 2, 3")
    }

    // MARK: - preview (perDay mode)

    @Test func preview_perDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start, mode: .perDay, intervalValue: 8,
            intervalUnit: .hours, durationDays: 2, timesPerDay: 3
        )
        #expect(dates.count == 6)
    }

    @Test func preview_perDay_singleDosePerDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start, mode: .perDay, intervalValue: 8,
            intervalUnit: .hours, durationDays: 3, timesPerDay: 1
        )
        #expect(dates.count == 3)
        let hoursBetween = dates[1].timeIntervalSince(dates[0]) / 3600
        #expect(Int(hoursBetween) == 24)
    }

    @Test func preview_perDay_oneDayOneDose() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start, mode: .perDay, intervalValue: 8,
            intervalUnit: .hours, durationDays: 1, timesPerDay: 1
        )
        #expect(dates.count == 1)
        #expect(dates.first == start)
    }

    // MARK: - intervalSummary

    @Test func intervalSummary_8HoursForOneDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let summary = MedicationScheduling.intervalSummary(
            start: start, durationDays: 1, stepValue: 8, stepUnit: .hours
        )
        let unwrapped = try! #require(summary, "Summary should not be nil for valid input")
        #expect(unwrapped.total == 4)
    }

    @Test func intervalSummary_dailyFor7Days() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let summary = MedicationScheduling.intervalSummary(
            start: start, durationDays: 7, stepValue: 1, stepUnit: .days
        )
        let unwrapped = try! #require(summary)
        #expect(unwrapped.total == 8, "7-day duration, daily: day 0..7 = 8 entries")
    }

    @Test func intervalSummary_weeklyFor1Month() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let summary = MedicationScheduling.intervalSummary(
            start: start, durationDays: 28, stepValue: 1, stepUnit: .weeks
        )
        let unwrapped = try! #require(summary)
        #expect(unwrapped.total == 5, "28-day duration, weekly: week 0..4 = 5 entries")
    }
}

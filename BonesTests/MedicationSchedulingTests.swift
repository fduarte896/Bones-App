import Foundation
import Testing
@testable import Bones

struct MedicationSchedulingTests {
    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return cal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
    
    @Test func intervalSummary_8HoursForOneDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let summary = MedicationScheduling.intervalSummary(
            start: start,
            durationDays: 1,
            stepValue: 8,
            stepUnit: .hours
        )
        #expect(summary?.total == 4)
        let expectedLast = MedicationScheduling.addInterval(24, unit: .hours, to: start)
        #expect(summary?.last == expectedLast)
    }
    
    @Test func preview_intervalHours() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start,
            mode: .interval,
            intervalValue: 8,
            intervalUnit: .hours,
            durationDays: 1,
            timesPerDay: 3
        )
        #expect(dates.count == 4)
        #expect(dates.first == start)
        let expectedLast = MedicationScheduling.addInterval(24, unit: .hours, to: start)
        #expect(dates.last == expectedLast)
    }
    
    @Test func preview_perDay() {
        let start = makeDate(year: 2026, month: 3, day: 7, hour: 8)
        let dates = MedicationScheduling.preview(
            start: start,
            mode: .perDay,
            intervalValue: 8,
            intervalUnit: .hours,
            durationDays: 2,
            timesPerDay: 3
        )
        #expect(dates.count == 6)
        let expectedLast = MedicationScheduling.addInterval(40, unit: .hours, to: start)
        #expect(dates.last == expectedLast)
    }
}

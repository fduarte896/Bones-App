import Testing
import Foundation
@testable import Bones

@Suite(.tags(.models))
struct RepeatRuleTests {
    @Test(arguments: [
        ("FREQ=MONTHLY;INTERVAL=3", RepeatRule(value: 3, unit: .months)),
        ("FREQ=YEARLY;INTERVAL=1", RepeatRule(value: 1, unit: .years)),
        ("freq=weekly;interval=2", RepeatRule(value: 2, unit: .weeks)),
        ("FREQ=DAILY", RepeatRule(value: 1, unit: .days))
    ])
    func parsesLegacyRRULE(text: String, expected: RepeatRule) {
        #expect(RepeatRule(rrule: text) == expected)
    }

    @Test(arguments: ["", "FREQ=HOURLY;INTERVAL=8", "INTERVAL=3", "tonterías"])
    func rejectsUnsupportedRRULE(text: String) {
        #expect(RepeatRule(rrule: text) == nil)
    }

    @Test func roundTripsThroughRRULE() {
        let rule = RepeatRule(value: 6, unit: .months)
        #expect(RepeatRule(rrule: rule.rrule) == rule)
    }

    @Test func nextDateAddsCalendarMonths() {
        let rule = RepeatRule(value: 3, unit: .months)
        let next = rule.next(after: makeDate(year: 2026, month: 11, day: 30), calendar: testCalendar)
        #expect(next == makeDate(year: 2027, month: 2, day: 28), "Febrero no tiene día 30")
    }

    @Test func neverRepeatsFasterThanOnce() {
        #expect(RepeatRule(value: 0, unit: .months).value == 1)
    }

    @Test(arguments: [
        (RepeatRule(value: 1, unit: .months), "Cada mes"),
        (RepeatRule(value: 3, unit: .months), "Cada 3 meses"),
        (RepeatRule(value: 1, unit: .years), "Cada año"),
        (RepeatRule(value: 12, unit: .weeks), "Cada 12 semanas")
    ])
    func labelReadsNaturally(rule: RepeatRule, expected: String) {
        #expect(rule.label == expected)
    }
}

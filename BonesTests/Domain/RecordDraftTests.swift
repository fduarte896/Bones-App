import Testing
import Foundation
@testable import Bones

@Suite(.tags(.logging))
struct RecordDraftTests {
    @Test(arguments: ["", "   ", "\n"])
    func aNameIsRequired(name: String) {
        #expect(RecordDraft(kind: .vaccine, name: name).isValid == false)
        #expect(RecordDraft(kind: .deworming, name: name).isValid == false)
    }

    @Test func aNamedRecordIsValid() {
        #expect(RecordDraft(kind: .deworming, name: "Drontal").isValid)
    }

    @Test(arguments: [nil, 0, -2, 500] as [Double?])
    func weightMustBeReasonable(kg: Double?) {
        #expect(RecordDraft(kind: .weight, weightKg: kg).isValid == false)
    }

    @Test(arguments: [0.3, 4.2, 62.5])
    func ordinaryWeightsAreValid(kg: Double) {
        #expect(RecordDraft(kind: .weight, weightKg: kg).isValid)
    }

    @Test func tomorrowIsPlannedButTodayIsNot() {
        let today = RecordDraft(kind: .vaccine, name: "Rabia", date: makeDate(day: 15, hour: 23))
        let tomorrow = RecordDraft(kind: .vaccine, name: "Rabia", date: makeDate(day: 16, hour: 0, minute: 5))
        #expect(today.isPlanned(now: testNow, calendar: testCalendar) == false)
        #expect(tomorrow.isPlanned(now: testNow, calendar: testCalendar))
    }

    @Test func weightIsNeverPlanned() {
        let draft = RecordDraft(kind: .weight, date: day(5), weightKg: 9)
        #expect(draft.isPlanned(now: testNow, calendar: testCalendar) == false)
    }

    @Test func nextDateOnlyExistsForAppliedRepeatingRecords() {
        let rule = RepeatRule(value: 3, unit: .months)
        let applied = RecordDraft(kind: .deworming, name: "Drontal", date: testNow, repeatRule: rule)
        let once = RecordDraft(kind: .deworming, name: "Drontal", date: testNow)
        let planned = RecordDraft(kind: .deworming, name: "Drontal", date: day(10), repeatRule: rule)

        #expect(applied.nextDate(now: testNow, calendar: testCalendar) == makeDate(month: 9, day: 15))
        #expect(once.nextDate(now: testNow, calendar: testCalendar) == nil)
        #expect(planned.nextDate(now: testNow, calendar: testCalendar) == nil)
    }
}

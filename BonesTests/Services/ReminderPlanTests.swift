import Testing
import Foundation
@testable import Bones

@Suite(.tags(.reminders))
struct ReminderPlanTests {
    private let due = makeDate(month: 7, day: 20, hour: 17)

    private func fireDates(leadDays: Int, now: Date = testNow) -> [Date] {
        ReminderPlan.fireDates(due: due, leadDays: leadDays, now: now, calendar: testCalendar)
    }

    @Test func remindsAheadAndOnTheDayAtNine() {
        #expect(fireDates(leadDays: 3) == [
            makeDate(month: 7, day: 17, hour: 9),
            makeDate(month: 7, day: 20, hour: 9)
        ])
    }

    @Test func zeroLeadDaysMeansOnlyTheSameDay() {
        #expect(fireDates(leadDays: 0) == [makeDate(month: 7, day: 20, hour: 9)])
    }

    @Test func skipsRemindersThatAlreadyPassed() {
        let twoDaysBefore = makeDate(month: 7, day: 18)
        #expect(fireDates(leadDays: 3, now: twoDaysBefore) == [makeDate(month: 7, day: 20, hour: 9)])
    }

    @Test func nothingToScheduleOnceTheDayIsUnderway() {
        let thatAfternoon = makeDate(month: 7, day: 20, hour: 15)
        #expect(fireDates(leadDays: 3, now: thatAfternoon).isEmpty)
    }

    @Test func plansHaveStableDistinctIdentifiersAndReadableText() {
        let id = UUID()
        let plans = ReminderPlan.plans(recordID: id, petName: "Marcos", subject: "Antirrábica",
                                       due: due, leadDays: 3, now: testNow, calendar: testCalendar)

        #expect(plans.map(\.identifier) == ["\(id.uuidString)-lead", "\(id.uuidString)-due"])
        #expect(plans.allSatisfy { $0.title == "Marcos" })
        #expect(plans.last?.body == "Antirrábica toca hoy.")
        #expect(plans.first?.body.hasPrefix("Antirrábica toca el 20") == true)
    }
}

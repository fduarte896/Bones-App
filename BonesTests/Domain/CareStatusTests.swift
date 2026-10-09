import Testing
import Foundation
@testable import Bones

@Suite(.tags(.summary))
struct CareStatusTests {
    private func status(last: Int?, next: Int?) -> CareStatus {
        CareStatus(lastDate: last.map(day), nextDate: next.map(day), now: testNow, calendar: testCalendar)
    }

    @Test func nothingRecorded() {
        #expect(status(last: nil, next: nil) == .unrecorded)
    }

    @Test func historyWithoutNextDate() {
        #expect(status(last: -40, next: nil) == .noNextDate)
    }

    @Test(arguments: [
        (-1, CareStatus.overdue(daysLate: 1)),
        (0, .dueSoon(daysLeft: 0)),
        (30, .dueSoon(daysLeft: 30)),
        (31, .upToDate(daysLeft: 31))
    ])
    func boundariesAroundToday(offset: Int, expected: CareStatus) {
        #expect(status(last: -90, next: offset) == expected)
    }

    @Test func dueTodayIsNotOverdueEvenLateInTheDay() {
        let dueThisMorning = makeDate(day: 15, hour: 8)
        let tonight = makeDate(day: 15, hour: 23)
        let status = CareStatus(lastDate: nil, nextDate: dueThisMorning, now: tonight, calendar: testCalendar)
        #expect(status == .dueSoon(daysLeft: 0))
    }

    @Test func onlySoonAndOverdueNeedAttention() {
        #expect(CareStatus.overdue(daysLate: 3).needsAttention)
        #expect(CareStatus.dueSoon(daysLeft: 3).needsAttention)
        #expect(CareStatus.upToDate(daysLeft: 60).needsAttention == false)
        #expect(CareStatus.noNextDate.needsAttention == false)
        #expect(CareStatus.unrecorded.needsAttention == false)
    }
}

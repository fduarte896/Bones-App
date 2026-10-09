import Testing
import Foundation
@testable import Bones

@Suite(.tags(.formatting))
struct BonesFormatTests {
    @Test(arguments: [
        (1, "1 día"), (10, "10 días"), (13, "13 días"),
        (14, "2 semanas"), (30, "4 semanas"), (55, "8 semanas"),
        (56, "2 meses"), (61, "2 meses"), (335, "11 meses"),
        (730, "2 años"), (1065, "2 años y 11 meses"), (1096, "3 años")
    ])
    func spanPicksTheNaturalUnit(days: Int, expected: String) {
        #expect(BonesFormat.span(days: days) == expected)
    }

    @Test(arguments: [
        (0, "Hoy"), (-1, "Ayer"), (-10, "Hace 10 días"), (-61, "Hace 2 meses"),
        (1, "Mañana"), (20, "En 3 semanas")
    ])
    func agoDescribesDistanceFromToday(offset: Int, expected: String) {
        #expect(BonesFormat.ago(day(offset), now: testNow, calendar: testCalendar) == expected)
    }

    @Test func agoIgnoresTimeOfDay() {
        let lateLastNight = makeDate(day: 14, hour: 23, minute: 50)
        let earlyThisMorning = makeDate(day: 15, hour: 0, minute: 10)
        #expect(BonesFormat.ago(lateLastNight, now: earlyThisMorning, calendar: testCalendar) == "Ayer")
    }

    @Test(arguments: [
        (CareStatus.overdue(daysLate: 1), "Tocaba ayer"),
        (.overdue(daysLate: 10), "Tocaba hace 10 días"),
        (.dueSoon(daysLeft: 0), "Toca hoy"),
        (.dueSoon(daysLeft: 1), "Toca mañana"),
        (.dueSoon(daysLeft: 12), "Toca en 12 días"),
        (.upToDate(daysLeft: 92), "Toca en 3 meses")
    ])
    func dueTextMatchesStatus(status: CareStatus, expected: String) {
        #expect(BonesFormat.dueText(for: status) == expected)
    }

    @Test(arguments: [CareStatus.unrecorded, .noNextDate])
    func dueTextIsEmptyWithoutANextDate(status: CareStatus) {
        #expect(BonesFormat.dueText(for: status) == nil)
    }

    @Test(arguments: [
        (makeDate(year: 2022, month: 6, day: 1), "4 años"),
        (makeDate(year: 2025, month: 6, day: 1), "1 año"),
        (makeDate(year: 2025, month: 10, day: 1), "8 meses"),
        (makeDate(year: 2026, month: 5, day: 20), "3 semanas"),
        (makeDate(year: 2026, month: 6, day: 13), "Recién nacido")
    ])
    func ageUsesTheLargestUnit(birthDate: Date, expected: String) {
        #expect(BonesFormat.age(from: birthDate, now: testNow, calendar: testCalendar) == expected)
    }

    @Test func weightDeltaShowsDirection() {
        #expect(BonesFormat.weightDelta(0.3).hasPrefix("+"))
        #expect(BonesFormat.weightDelta(-0.3).hasPrefix("−"))
    }
}

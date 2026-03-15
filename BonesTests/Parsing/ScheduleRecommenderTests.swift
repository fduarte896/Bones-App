import Testing
import Foundation
@testable import Bones

@Suite(.tags(.parsing, .scheduling))
struct ScheduleRecommenderTests {
    let recommender = ScheduleRecommender()
    let start = makeDate(year: 2026, month: 6, day: 1, hour: 10)

    // MARK: - recommendVaccineSeries

    @Test func recommendVaccineSeries_rabia_produces4Events() {
        let events = recommender.recommendVaccineSeries(baseName: "rabia", start: start)
        #expect(events.count == 4, "3 doses + 1 booster = 4 events")
    }

    @Test func recommendVaccineSeries_rabia_doseLabeling() {
        let events = recommender.recommendVaccineSeries(baseName: "rabia", start: start)
        #expect(events[0].fullName.contains("dosis 1/3"))
        #expect(events[1].fullName.contains("dosis 2/3"))
        #expect(events[2].fullName.contains("dosis 3/3"))
    }

    @Test func recommendVaccineSeries_rabia_boosterHasFrequencyRefuerzo() {
        let events = recommender.recommendVaccineSeries(baseName: "rabia", start: start)
        let booster = try! #require(events.last)
        #expect(booster.frequency == "refuerzo")
    }

    @Test func recommendVaccineSeries_dateSpacing() {
        let events = recommender.recommendVaccineSeries(baseName: "rabia", start: start)
        let daysBetween01 = events[1].date.timeIntervalSince(events[0].date) / 86400
        let daysBetween12 = events[2].date.timeIntervalSince(events[1].date) / 86400
        #expect(Int(daysBetween01) == 21)
        #expect(Int(daysBetween12) == 21)
    }

    @Test func recommendVaccineSeries_unknownVaccine_singleEvent() {
        let events = recommender.recommendVaccineSeries(baseName: "desconocida", start: start)
        #expect(events.count == 1)
    }

    @Test func recommendVaccineSeries_moquillo_samePatternAsRabia() {
        let events = recommender.recommendVaccineSeries(baseName: "moquillo", start: start)
        #expect(events.count == 4)
    }

    // MARK: - recommendMedicationSeries

    @Test func recommendMedicationSeries_defaultInterval8h() {
        let events = recommender.recommendMedicationSeries(baseName: "ibuprofeno", start: start, totalDoses: 3)
        let hoursBetween = events[1].date.timeIntervalSince(events[0].date) / 3600
        #expect(Int(hoursBetween) == 8, "Unknown medication should default to 8h")
    }

    @Test func recommendMedicationSeries_knownMedAmoxicilina8h() {
        let events = recommender.recommendMedicationSeries(baseName: "amoxicilina", start: start, totalDoses: 3)
        let hoursBetween = events[1].date.timeIntervalSince(events[0].date) / 3600
        #expect(Int(hoursBetween) == 8)
    }

    @Test func recommendMedicationSeries_customIntervalOverride() {
        let events = recommender.recommendMedicationSeries(baseName: "amoxicilina", start: start, hoursInterval: 12, totalDoses: 2)
        let hoursBetween = events[1].date.timeIntervalSince(events[0].date) / 3600
        #expect(Int(hoursBetween) == 12, "Custom interval should override default")
    }

    @Test func recommendMedicationSeries_doseLabelingMultiple() {
        let events = recommender.recommendMedicationSeries(baseName: "Test", start: start, totalDoses: 3)
        #expect(events[0].fullName.contains("dosis 1/3"))
        #expect(events[1].fullName.contains("dosis 2/3"))
        #expect(events[2].fullName.contains("dosis 3/3"))
    }
}

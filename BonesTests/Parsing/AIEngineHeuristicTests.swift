import Testing
import Foundation
@testable import Bones

@Suite(.tags(.parsing))
struct AIEngineHeuristicTests {
    let reference = makeDate(year: 2026, month: 6, day: 15, hour: 10)

    // MARK: - parseQuickAdd (falls through to heuristic in tests)

    @Test func parseQuickAdd_detectsVaccineKeywords() async {
        let result = await AIEngine.shared.parseQuickAdd(text: "vacuna rabia")
        let event = try! #require(result.events.first)
        #expect(event.kind == .vaccine)
    }

    @Test func parseQuickAdd_detectsDewormingKeywords() async {
        let result = await AIEngine.shared.parseQuickAdd(text: "drontal plus")
        let event = try! #require(result.events.first)
        #expect(event.kind == .deworming)
    }

    @Test func parseQuickAdd_emptyText_returnsWarning() async {
        let result = await AIEngine.shared.parseQuickAdd(text: "")
        #expect(result.events.isEmpty)
    }

    @Test func parseQuickAdd_extractsDosage() async {
        let result = await AIEngine.shared.parseQuickAdd(text: "amoxicilina 500mg cada 8 horas")
        let event = try! #require(result.events.first)
        #expect(event.dosage?.contains("500") == true)
    }

    @Test func parseQuickAdd_extractsFrequency() async {
        let result = await AIEngine.shared.parseQuickAdd(text: "medicamento cada 8 horas")
        let event = try! #require(result.events.first)
        let freq = try! #require(event.frequency)
        #expect(freq.contains("8"))
    }

    // MARK: - recommendSeries

    @Test func recommendSeries_vaccine_multipleResults() async {
        let result = await AIEngine.shared.recommendSeries(
            for: .vaccine, baseName: "rabia",
            start: reference, dosage: nil, hoursInterval: nil, totalDoses: nil
        )
        #expect(result.count > 1, "Vaccine series should produce multiple suggestions")
    }

    @Test func recommendSeries_medication_customDoses() async {
        let result = await AIEngine.shared.recommendSeries(
            for: .medication, baseName: "test",
            start: reference, dosage: nil, hoursInterval: 8, totalDoses: 5
        )
        #expect(result.count == 5)
    }

    @Test func recommendSeries_grooming_singleResult() async {
        let result = await AIEngine.shared.recommendSeries(
            for: .grooming, baseName: "baño",
            start: reference, dosage: nil, hoursInterval: nil, totalDoses: nil
        )
        #expect(result.count == 1, "Non-medication/vaccine kinds should return single date")
    }
}

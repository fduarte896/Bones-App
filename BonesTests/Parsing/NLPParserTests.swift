import Testing
import Foundation
@testable import Bones

@Suite(.tags(.parsing))
struct NLPParserTests {
    let parser = NLPParser()
    let reference = makeDate(year: 2026, month: 6, day: 15, hour: 10)

    // MARK: - extractFromOCR: Kind detection

    @Test func extractFromOCR_detectsVaccineKind() {
        let result = parser.extractFromOCR("Vacuna antirrábica\n250 mg\ncada 12 h", now: reference)
        #expect(result.kind == .vaccine)
    }

    @Test func extractFromOCR_detectsDewormingKind() {
        let result = parser.extractFromOCR("Endogard Plus cada 3 meses", now: reference)
        #expect(result.kind == .deworming)
    }

    @Test func extractFromOCR_detectsMedicationByDosage() {
        let result = parser.extractFromOCR("Amoxicilina 500 mg cada 8 horas", now: reference)
        #expect(result.kind == .medication)
    }

    // MARK: - extractFromOCR: Field extraction

    @Test func extractFromOCR_extractsDosage() {
        let result = parser.extractFromOCR("Amoxicilina 500 mg cada 8 horas", now: reference)
        #expect(result.dosage == "500 mg")
    }

    @Test func extractFromOCR_extractsFrequency() {
        let result = parser.extractFromOCR("medicamento cada 12 horas", now: reference)
        #expect(result.frequency == "cada 12 h")
    }

    @Test func extractFromOCR_extractsManufacturer() {
        let result = parser.extractFromOCR("fabricante: Pfizer Animal Health", now: reference)
        let manufacturer = try! #require(result.manufacturer)
        #expect(manufacturer.contains("Pfizer"))
    }

    // MARK: - extractFromOCR: Date inference

    @Test func extractFromOCR_dateFromHoy() {
        let result = parser.extractFromOCR("Amoxicilina hoy", now: reference)
        let date = try! #require(result.date)
        let cal = Calendar.current
        #expect(cal.isDate(date, inSameDayAs: reference))
    }

    @Test func extractFromOCR_dateFromManana() {
        let result = parser.extractFromOCR("Vacuna mañana", now: reference)
        let date = try! #require(result.date)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: reference)!
        #expect(Calendar.current.isDate(date, inSameDayAs: tomorrow))
    }

    // MARK: - extractFromOCR: Confidence

    @Test func extractFromOCR_confidence_fullInfo() {
        let text = "Amoxicilina 500 mg cada 8 horas hoy"
        let result = parser.extractFromOCR(text, now: reference)
        #expect(result.confidence >= 0.8, "Full info should yield high confidence")
    }

    @Test func extractFromOCR_confidence_noRecognizableFields() {
        let result = parser.extractFromOCR("hello world", now: reference)
        #expect(result.confidence < 0.3, "Unrecognizable text should yield low confidence")
    }

    // MARK: - parseQuickAdd: Empty input

    @Test func parseQuickAdd_emptyReturnsWarning() {
        let result = parser.parseQuickAdd("", reference: reference)
        #expect(result.events.isEmpty)
        #expect(result.warnings.isEmpty == false)
    }

    // MARK: - parseQuickAdd: Kind detection

    @Test func parseQuickAdd_detectsVaccine() {
        let result = parser.parseQuickAdd("vacuna rabia mañana 10am", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.kind == .vaccine)
    }

    @Test func parseQuickAdd_detectsDeworming() {
        let result = parser.parseQuickAdd("desparasitación endogard", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.kind == .deworming)
    }

    @Test func parseQuickAdd_detectsGrooming() {
        let result = parser.parseQuickAdd("baño y corte de pelo", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.kind == .grooming)
    }

    @Test func parseQuickAdd_detectsWeight() {
        let result = parser.parseQuickAdd("peso 25 kg", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.kind == .weight)
    }

    @Test func parseQuickAdd_defaultsToMedication() {
        let result = parser.parseQuickAdd("amoxicilina cada 8 horas", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.kind == .medication)
    }

    // MARK: - parseQuickAdd: Field extraction

    @Test func parseQuickAdd_extractsDosage() {
        let result = parser.parseQuickAdd("amoxicilina 250 mg", reference: reference)
        let event = try! #require(result.events.first)
        #expect(event.dosage?.contains("250") == true)
    }

    @Test func parseQuickAdd_extractsFrequency() {
        let result = parser.parseQuickAdd("amoxicilina cada 12 horas", reference: reference)
        let event = try! #require(result.events.first)
        let freq = try! #require(event.frequency)
        #expect(freq.contains("cada 12"))
    }

    // MARK: - parseQuickAdd: Date inference

    @Test func parseQuickAdd_dateFromManana() {
        let result = parser.parseQuickAdd("vacuna mañana", reference: reference)
        let event = try! #require(result.events.first)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: reference)!
        #expect(Calendar.current.isDate(event.date, inSameDayAs: tomorrow))
    }

    @Test func parseQuickAdd_dateEnXDias() {
        let result = parser.parseQuickAdd("vacuna en 3 días", reference: reference)
        let event = try! #require(result.events.first)
        let expected = Calendar.current.date(byAdding: .day, value: 3, to: reference)!
        #expect(Calendar.current.isDate(event.date, inSameDayAs: expected))
    }
}

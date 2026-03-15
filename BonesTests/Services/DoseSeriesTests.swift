import Testing
import Foundation
import SwiftData
@testable import Bones

// MARK: - Pure parsing tests (no SwiftData)

@Suite(.tags(.parsing))
struct DoseSeriesParsingTests {

    // MARK: - splitDoseBase

    @Test func splitDoseBase_withDoseLabel() {
        let result = DoseSeries.splitDoseBase(from: "Rabia (dosis 2/3)")
        #expect(result == "Rabia")
    }

    @Test func splitDoseBase_withoutDoseLabel() {
        let result = DoseSeries.splitDoseBase(from: "Rabia")
        #expect(result == "Rabia")
    }

    @Test func splitDoseBase_emptyString() {
        let result = DoseSeries.splitDoseBase(from: "")
        #expect(result == "")
    }

    // MARK: - splitDose

    @Test func splitDose_withNumbers() {
        let result = DoseSeries.splitDose(from: "Rabia (dosis 2/3)")
        #expect(result.base == "Rabia")
        #expect(result.dose == "Dosis 2/3")
    }

    @Test func splitDose_withoutNumbers() {
        let result = DoseSeries.splitDose(from: "Rabia")
        #expect(result.base == "Rabia")
        #expect(result.dose == nil)
    }

    @Test func splitDose_caseInsensitive_markerMismatch() {
        // Production uses lowercase " (dosis " as the marker,
        // so capital-D "Dosis" does not match and returns no split.
        let result = DoseSeries.splitDose(from: "Rabia (Dosis 1/2)")
        #expect(result.base == "Rabia (Dosis 1/2)")
        #expect(result.dose == nil)
    }

    // MARK: - parseDoseNumbers (parameterized)

    @Test(arguments: [
        ("Rabia (dosis 2/3)", 2, 3),
        ("Rabia (dosis 1/1)", 1, 1),
        ("Moquillo (dosis 10/12)", 10, 12),
    ])
    func parseDoseNumbers_extractsCorrectly(name: String, expectedCurrent: Int, expectedTotal: Int) {
        let result = DoseSeries.parseDoseNumbers(from: name)
        #expect(result.current == expectedCurrent)
        #expect(result.total == expectedTotal)
    }

    @Test func parseDoseNumbers_noDoseLabel_returnsNils() {
        let result = DoseSeries.parseDoseNumbers(from: "Rabia")
        #expect(result.current == nil)
        #expect(result.total == nil)
    }

    // MARK: - normalizeNotes

    @Test func normalizeNotes_trims() {
        #expect(DoseSeries.normalizeNotes("  Drontal Plus  ") == "drontal plus")
    }

    @Test func normalizeNotes_nil() {
        #expect(DoseSeries.normalizeNotes(nil) == "")
    }

    @Test func normalizeNotes_empty() {
        #expect(DoseSeries.normalizeNotes("") == "")
    }
}

// MARK: - SwiftData-dependent tests

@MainActor
@Suite(.tags(.parsing, .models))
struct DoseSeriesDataTests {

    let context: ModelContext

    init() throws {
        context = try makeContext()
    }

    @Test func isBooster_trueBeyondThreshold() throws {
        let pet = makePet(in: context)
        let v1 = Vaccine(date: makeDate(year: 2025, month: 1, day: 1), pet: pet, vaccineName: "Rabia (dosis 1/1)")
        let v2 = Vaccine(date: makeDate(year: 2025, month: 12, day: 1), pet: pet, vaccineName: "Rabia")
        context.insert(v1)
        context.insert(v2)
        try context.save()

        #expect(DoseSeries.isBooster(v2, among: [v1, v2]) == true)
    }

    @Test func isBooster_falseBelowThreshold() throws {
        let pet = makePet(in: context)
        let v1 = Vaccine(date: makeDate(year: 2026, month: 1, day: 1), pet: pet, vaccineName: "Rabia (dosis 1/3)")
        let v2 = Vaccine(date: makeDate(year: 2026, month: 1, day: 22), pet: pet, vaccineName: "Rabia (dosis 2/3)")
        context.insert(v1)
        context.insert(v2)
        try context.save()

        #expect(DoseSeries.isBooster(v2, among: [v1, v2]) == false)
    }

    @Test func isBooster_falseForFirst() throws {
        let pet = makePet(in: context)
        let v1 = Vaccine(date: makeDate(year: 2026, month: 1, day: 1), pet: pet, vaccineName: "Rabia (dosis 1/3)")
        context.insert(v1)
        try context.save()

        #expect(DoseSeries.isBooster(v1, among: [v1]) == false)
    }

    @Test func futureMedications_filtersByBase() throws {
        let pet = makePet(in: context)
        let m1 = Medication(date: makeDate(day: 15), pet: pet, name: "Amoxicilina (dosis 1/3)", dosage: "500mg", frequency: "8h")
        let m2 = Medication(date: makeDate(day: 16), pet: pet, name: "Amoxicilina (dosis 2/3)", dosage: "500mg", frequency: "8h")
        let m3 = Medication(date: makeDate(day: 16), pet: pet, name: "Ibuprofeno", dosage: "200mg", frequency: "12h")
        context.insert(m1)
        context.insert(m2)
        context.insert(m3)
        try context.save()

        let result = DoseSeries.futureMedications(from: m1, in: context)
        #expect(result.count == 2, "Should find 2 Amoxicilina meds, not Ibuprofeno")
    }

    @Test func futureDewormings_matchesBySeriesID() throws {
        let pet = makePet(in: context)
        let seriesID = UUID()
        let d1 = Deworming(date: makeDate(day: 15), pet: pet, notes: "Drontal", seriesID: seriesID)
        let d2 = Deworming(date: makeDate(day: 20), pet: pet, notes: "Drontal", seriesID: seriesID)
        let d3 = Deworming(date: makeDate(day: 20), pet: pet, notes: "Endogard", seriesID: UUID())
        context.insert(d1)
        context.insert(d2)
        context.insert(d3)
        try context.save()

        let result = DoseSeries.futureDewormings(from: d1, in: context)
        #expect(result.count == 2, "Should match by seriesID, excluding Endogard")
    }
}

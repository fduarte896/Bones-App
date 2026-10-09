import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.migration))
struct LegacyDataMigratorTests {
    let context: ModelContext
    let pet: Pet

    init() throws {
        context = try makeContext()
        pet = try makePet(in: context)
    }

    /// Una desparasitación tal como la guardaban las versiones anteriores: el producto en las notas.
    private func legacyDeworming(notes: String?, applied: Bool = true) -> Deworming {
        let record = Deworming(date: day(-10), pet: pet, notes: notes)
        record.isCompleted = applied
        context.insert(record)
        return record
    }

    @Test func movesTheProductOutOfTheNotes() throws {
        let record = legacyDeworming(notes: "Drontal Plus (dosis 1/2)")
        try LegacyDataMigrator.migrate(context: context)

        #expect(record.productName == "Drontal Plus")
        #expect(record.notes == "Dosis 1/2")
        #expect(record.kind == .internal)
    }

    @Test func plainProductLeavesNoNotesBehind() throws {
        let record = legacyDeworming(notes: "milbemax")
        try LegacyDataMigrator.migrate(context: context)

        #expect(record.productName == "Milbemax")
        #expect(record.notes == nil)
    }

    @Test(arguments: ["Bravecto", "NexGard Spectra", "Pipeta mensual", "Collar Seresto"])
    func recognizesFleaAndTickProducts(product: String) throws {
        let record = legacyDeworming(notes: product)
        try LegacyDataMigrator.migrate(context: context)
        #expect(record.kind == .external)
    }

    @Test func keepsAppliedAndPendingAsTheyWere() throws {
        let done = legacyDeworming(notes: "Drontal", applied: true)
        let waiting = legacyDeworming(notes: "Drontal", applied: false)
        try LegacyDataMigrator.migrate(context: context)

        #expect(done.isCompleted)
        #expect(waiting.isCompleted == false)
        #expect(try context.fetchCount(FetchDescriptor<Deworming>()) == 2, "La migración no borra nada")
    }

    @Test func recordsWithoutAProductStayUntouched() throws {
        let record = legacyDeworming(notes: nil)
        try LegacyDataMigrator.migrate(context: context)
        #expect(record.productName.isEmpty)
        #expect(record.notes == nil)
    }

    @Test func movesTheDoseOutOfVaccineNames() throws {
        let withNotes = Vaccine(date: day(-5), pet: pet, vaccineName: "Rabia (dosis 2/3)", notes: "Pata derecha")
        let plain = Vaccine(date: day(-5), pet: pet, vaccineName: "Polivalente (DHPPi)", notes: "Sin reacción")
        context.insert(withNotes)
        context.insert(plain)
        try LegacyDataMigrator.migrate(context: context)

        #expect(withNotes.vaccineName == "Rabia")
        #expect(withNotes.notes == "Dosis 2/3 · Pata derecha")
        #expect(plain.vaccineName == "Polivalente (DHPPi)")
        #expect(plain.notes == "Sin reacción")
    }

    @Test func runningTwiceChangesNothingMore() throws {
        let record = legacyDeworming(notes: "Drontal Plus (dosis 1/2)")
        try LegacyDataMigrator.migrate(context: context)
        try LegacyDataMigrator.migrate(context: context)

        #expect(record.productName == "Drontal Plus")
        #expect(record.notes == "Dosis 1/2")
    }

    @Test func runIfNeededOnlyRunsOnce() throws {
        let suiteName = "LegacyDataMigratorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = legacyDeworming(notes: "Drontal")
        LegacyDataMigrator.runIfNeeded(context: context, defaults: defaults)
        #expect(first.productName == "Drontal")

        // Un registro nuevo sin producto y con notas de verdad no debe confundirse con uno antiguo.
        let later = legacyDeworming(notes: "Le sentó mal")
        LegacyDataMigrator.runIfNeeded(context: context, defaults: defaults)
        #expect(later.productName.isEmpty)
        #expect(later.notes == "Le sentó mal")
    }
}

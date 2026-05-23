import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.models))
struct EventTests {
    let context: ModelContext
    let pet: Pet

    init() throws {
        context = try makeContext()
        pet = makePet(in: context)
    }

    // MARK: - displayName

    @Test func displayName_vaccine_returnsVaccineName() {
        let vac = Vaccine(date: Date(), pet: pet, vaccineName: "Rabia")
        context.insert(vac)
        #expect(vac.displayName == "Rabia")
    }

    @Test func displayName_deworming_withNotes() {
        let dew = Deworming(date: Date(), pet: pet, notes: "Drontal")
        context.insert(dew)
        #expect(dew.displayName == "Drontal")
    }

    @Test func displayName_deworming_emptyNotes() {
        let dew = Deworming(date: Date(), pet: pet)
        context.insert(dew)
        #expect(dew.displayName == "Desparasitación")
    }

    @Test func displayName_weightEntry() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 25.3)
        context.insert(w)
        #expect(w.displayName == "Peso: 25.3 kg")
    }

    // MARK: - displayType

    @Test func displayType_vaccine() {
        let vac = Vaccine(date: Date(), pet: pet, vaccineName: "Test")
        context.insert(vac)
        #expect((vac as any BasicEvent).displayType == "Vacuna")
    }

    @Test func displayType_deworming() {
        let dew = Deworming(date: Date(), pet: pet)
        context.insert(dew)
        #expect((dew as any BasicEvent).displayType == "Desparasitación")
    }

    @Test func displayType_weightEntry() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 10)
        context.insert(w)
        #expect((w as any BasicEvent).displayType == "Registro de peso")
    }

    // MARK: - WeightEntry defaults

    @Test func weightEntry_isAlwaysCompleted() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 10)
        context.insert(w)
        #expect(w.isCompleted == true)
    }
}

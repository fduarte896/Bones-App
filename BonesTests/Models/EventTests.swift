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

    @Test func displayName_medication_returnsName() throws {
        let med = Medication(date: Date(), pet: pet, name: "Amoxicilina", dosage: "500mg", frequency: "8h")
        context.insert(med)
        #expect(med.displayName == "Amoxicilina")
    }

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

    @Test func displayName_grooming_withServices() {
        let g = Grooming(date: Date(), pet: pet, services: [.bano, .cortePelo])
        context.insert(g)
        #expect(g.displayName == "Baño, Corte de pelo")
    }

    @Test func displayName_grooming_noServices_withNotes() {
        let g = Grooming(date: Date(), pet: pet, notes: "Special grooming")
        context.insert(g)
        #expect(g.displayName == "Special grooming")
    }

    @Test func displayName_weightEntry() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 25.3)
        context.insert(w)
        #expect(w.displayName == "Peso: 25.3 kg")
    }

    // MARK: - displayType

    @Test func displayType_medication() {
        let med = Medication(date: Date(), pet: pet, name: "Test", dosage: "10mg", frequency: "8h")
        context.insert(med)
        #expect((med as any BasicEvent).displayType == "Medicamento")
    }

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

    @Test func displayType_grooming() {
        let g = Grooming(date: Date(), pet: pet)
        context.insert(g)
        #expect((g as any BasicEvent).displayType == "Peluquería")
    }

    @Test func displayType_weightEntry() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 10)
        context.insert(w)
        #expect((w as any BasicEvent).displayType == "Registro de peso")
    }

    // MARK: - Grooming.services transient property

    @Test func groomingServices_setAndGet() {
        let g = Grooming(date: Date(), pet: pet, services: [.bano, .limpiezaOjos])
        context.insert(g)
        #expect(g.services == [.bano, .limpiezaOjos])
    }

    @Test func groomingServices_emptyByDefault() {
        let g = Grooming(date: Date(), pet: pet)
        context.insert(g)
        #expect(g.services.isEmpty)
    }

    @Test func groomingServices_persistsViaServiceCodes() {
        let g = Grooming(date: Date(), pet: pet)
        context.insert(g)
        g.services = [.bano, .limpiezaOjos]
        #expect(g.serviceCodes.contains("bano"))
        #expect(g.serviceCodes.contains("limpiezaOjos"))
    }

    // MARK: - GroomingService.displayName

    @Test(arguments: GroomingService.allCases)
    func groomingService_displayName_nonEmpty(service: GroomingService) {
        #expect(service.displayName.isEmpty == false)
    }

    // MARK: - WeightEntry defaults

    @Test func weightEntry_isAlwaysCompleted() {
        let w = WeightEntry(date: Date(), pet: pet, weightKg: 10)
        context.insert(w)
        #expect(w.isCompleted == true)
    }
}

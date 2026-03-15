import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.models))
struct PetTests {
    let context: ModelContext

    init() throws {
        context = try makeContext()
    }

    @Test func pet_defaultValues() {
        let pet = Pet(name: "Luna")
        context.insert(pet)
        #expect(pet.species == .perro)
        #expect(pet.sex == .unknown)
        #expect(pet.breed == nil)
        #expect(pet.birthDate == nil)
    }

    @Test func pet_uniqueID() {
        let pet1 = Pet(name: "Luna")
        let pet2 = Pet(name: "Max")
        context.insert(pet1)
        context.insert(pet2)
        #expect(pet1.id != pet2.id)
    }

    @Test func species_allCases() {
        #expect(Species.allCases.count == 2)
        #expect(Species.allCases.contains(.perro))
        #expect(Species.allCases.contains(.gato))
    }

    @Test func pet_cascadeDelete_removesMedications() throws {
        let pet = makePet(in: context)
        let med = Medication(date: Date(), pet: pet, name: "Test", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let medsBefore = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        #expect(medsBefore.count == 1)

        context.delete(pet)
        try context.save()

        let medsAfter = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        #expect(medsAfter.isEmpty, "Cascade delete should remove medication when pet is deleted")
    }

    @Test func pet_cascadeDelete_removesAllEventTypes() throws {
        let pet = makePet(in: context)
        context.insert(Medication(date: Date(), pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: Date(), pet: pet, vaccineName: "Rabia"))
        context.insert(Deworming(date: Date(), pet: pet))
        context.insert(Grooming(date: Date(), pet: pet))
        context.insert(WeightEntry(date: Date(), pet: pet, weightKg: 10))
        try context.save()

        context.delete(pet)
        try context.save()

        #expect(((try? context.fetch(FetchDescriptor<Medication>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<Vaccine>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<Deworming>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<Grooming>())) ?? []).isEmpty)
        #expect(((try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []).isEmpty)
    }
}

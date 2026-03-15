import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.viewModels))
struct PetDetailViewModelTests {
    let context: ModelContext
    let pet: Pet
    let vm: PetDetailViewModel

    init() throws {
        context = try makeContext()
        pet = makePet(in: context, name: "Luna")
        vm = PetDetailViewModel(petID: pet.id)
        vm.inject(context: context)
    }

    // MARK: - fetchEvents

    @Test func fetchEvents_noEvents_emptyGrouped() {
        #expect(vm.groupedUpcomingEvents.isEmpty)
    }

    @Test func fetchEvents_futureEvent_appearsInSections() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Future Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()
        vm.fetchEvents()

        let allItems = vm.groupedUpcomingEvents.flatMap(\.items)
        #expect(allItems.isEmpty == false)
    }

    @Test func fetchEvents_pastEvents_excluded() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let med = Medication(date: pastDate, pet: pet, name: "Past Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()
        vm.fetchEvents()

        let allItems = vm.groupedUpcomingEvents.flatMap(\.items)
        #expect(allItems.isEmpty, "Past events should not appear in upcoming")
    }

    @Test func fetchEvents_completedEvents_excluded() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Done Med", dosage: "10mg", frequency: "8h")
        med.isCompleted = true
        context.insert(med)
        try context.save()
        vm.fetchEvents()

        let allItems = vm.groupedUpcomingEvents.flatMap(\.items)
        #expect(allItems.isEmpty, "Completed events should not appear in upcoming")
    }

    // MARK: - Filtered computed properties

    @Test func medications_filteredByPet() throws {
        let pet2 = makePet(in: context, name: "Max")
        context.insert(Medication(date: Date(), pet: pet, name: "Luna's Med", dosage: "10mg", frequency: "8h"))
        context.insert(Medication(date: Date(), pet: pet2, name: "Max's Med", dosage: "10mg", frequency: "8h"))
        try context.save()

        #expect(vm.medications.count == 1)
        #expect(vm.medications.first?.name == "Luna's Med")
    }

    @Test func vaccines_filteredByPet() throws {
        let pet2 = makePet(in: context, name: "Max")
        context.insert(Vaccine(date: Date(), pet: pet, vaccineName: "Rabia"))
        context.insert(Vaccine(date: Date(), pet: pet2, vaccineName: "Moquillo"))
        try context.save()

        #expect(vm.vaccines.count == 1)
        #expect(vm.vaccines.first?.vaccineName == "Rabia")
    }

    // MARK: - Weights

    @Test func weights_sortedByDateDesc() throws {
        context.insert(WeightEntry(date: makeDate(day: 1), pet: pet, weightKg: 10.0))
        context.insert(WeightEntry(date: makeDate(day: 15), pet: pet, weightKg: 12.0))
        context.insert(WeightEntry(date: makeDate(day: 10), pet: pet, weightKg: 11.0))
        try context.save()

        #expect(vm.weights.count == 3)
        #expect(vm.weights.first?.weightKg == 12.0, "Most recent should be first")
    }

    @Test func currentWeight_returnsMostRecent() throws {
        context.insert(WeightEntry(date: makeDate(day: 1), pet: pet, weightKg: 10.0))
        context.insert(WeightEntry(date: makeDate(day: 15), pet: pet, weightKg: 12.0))
        try context.save()

        let current = try #require(vm.currentWeight)
        #expect(current.weightKg == 12.0)
    }

    @Test func deltaDescription_twoWeights_showsDifference() throws {
        context.insert(WeightEntry(date: makeDate(day: 1), pet: pet, weightKg: 10.0))
        context.insert(WeightEntry(date: makeDate(day: 15), pet: pet, weightKg: 12.0))
        try context.save()

        #expect(vm.deltaDescription == "+2.0 kg")
    }

    @Test func deltaDescription_equalWeights() throws {
        context.insert(WeightEntry(date: makeDate(day: 1), pet: pet, weightKg: 10.0))
        context.insert(WeightEntry(date: makeDate(day: 15), pet: pet, weightKg: 10.0))
        try context.save()

        #expect(vm.deltaDescription == "0 kg")
    }

    @Test func deltaDescription_oneWeight_returnsDash() throws {
        context.insert(WeightEntry(date: makeDate(day: 1), pet: pet, weightKg: 10.0))
        try context.save()

        #expect(vm.deltaDescription == "–")
    }

    // MARK: - toggleCompleted

    @Test func toggleCompleted_updatesEvent() throws {
        let med = Medication(date: Date(), pet: pet, name: "Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        vm.toggleCompleted(med)
        #expect(med.isCompleted == true)
        #expect(med.completedAt != nil)
    }

    // MARK: - vaccineSeriesSummaries

    @Test func vaccineSeriesSummaries_groupsByBaseName() throws {
        context.insert(Vaccine(date: makeDate(day: 1), pet: pet, vaccineName: "Rabia (dosis 1/3)"))
        context.insert(Vaccine(date: makeDate(day: 22), pet: pet, vaccineName: "Rabia (dosis 2/3)"))
        try context.save()

        let summaries = vm.vaccineSeriesSummaries
        #expect(summaries.count == 1)
        #expect(summaries.first?.baseName == "Rabia")
        #expect(summaries.first?.items.count == 2)
    }
}

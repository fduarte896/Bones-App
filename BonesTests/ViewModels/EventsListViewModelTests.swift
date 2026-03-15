import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.viewModels))
struct EventsListViewModelTests {
    let context: ModelContext
    let pet: Pet

    init() throws {
        context = try makeContext()
        pet = makePet(in: context, name: "Luna")
    }

    private func makeVM() -> EventsListViewModel {
        EventsListViewModel(context: context)
    }

    // MARK: - Basic fetch

    @Test func init_emptyDatabase_noSections() {
        let vm = makeVM()
        #expect(vm.sections.isEmpty)
    }

    @Test func fetchAllEvents_medicationIncluded() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Amoxicilina", dosage: "500mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let vm = makeVM()
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.isEmpty == false, "Future medication should appear in sections")
    }

    // MARK: - Type filter

    @Test func filter_medication_onlyShowsMedications() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: futureDate, pet: pet, vaccineName: "Rabia"))
        try context.save()

        let vm = makeVM()
        vm.filter = .medication
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.allSatisfy { $0 is Medication })
    }

    @Test func filter_vaccine_onlyShowsVaccines() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: futureDate, pet: pet, vaccineName: "Rabia"))
        try context.save()

        let vm = makeVM()
        vm.filter = .vaccine
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.allSatisfy { $0 is Vaccine })
    }

    @Test func filter_all_showsEverything() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: futureDate, pet: pet, vaccineName: "Rabia"))
        try context.save()

        let vm = makeVM()
        vm.filter = .all
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.count == 2)
    }

    // MARK: - Pet filter

    @Test func petFilter_filtersCorrectly() throws {
        let pet2 = makePet(in: context, name: "Max")
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Luna's Med", dosage: "10mg", frequency: "8h"))
        context.insert(Medication(date: futureDate, pet: pet2, name: "Max's Med", dosage: "10mg", frequency: "8h"))
        try context.save()

        let vm = makeVM()
        vm.petFilter = PetFilter(id: pet.id, name: pet.name)
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.count == 1)
        let med = try #require(allItems.first as? Medication)
        #expect(med.name == "Luna's Med")
    }

    // MARK: - Search

    @Test func searchQuery_matchesByDisplayName() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Amoxicilina", dosage: "500mg", frequency: "8h"))
        try context.save()

        let vm = makeVM()
        vm.searchQuery = "amoxi"
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.isEmpty == false)
    }

    @Test func searchQuery_matchesByPetName() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        try context.save()

        let vm = makeVM()
        vm.searchQuery = "Luna"
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.isEmpty == false)
    }

    @Test func searchQuery_emptyString_showsAll() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        try context.save()

        let vm = makeVM()
        vm.searchQuery = ""
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.isEmpty == false)
    }

    @Test func searchQuery_noMatch_emptySections() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        context.insert(Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        try context.save()

        let vm = makeVM()
        vm.searchQuery = "xyznotfound"
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.isEmpty)
    }

    // MARK: - Toggle & Delete

    @Test func toggleCompleted_marksEventCompleted() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let vm = makeVM()
        vm.toggleCompleted(med)
        #expect(med.isCompleted == true)
        #expect(med.completedAt != nil)
    }

    @Test func toggleCompleted_secondToggle_unmarksCompleted() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let vm = makeVM()
        vm.toggleCompleted(med)
        vm.toggleCompleted(med)
        #expect(med.isCompleted == false)
        #expect(med.completedAt == nil)
    }

    @Test func delete_removesEvent() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let med = Medication(date: futureDate, pet: pet, name: "Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let vm = makeVM()
        #expect(vm.sections.flatMap(\.items).isEmpty == false)
        vm.delete(med)
        #expect(vm.sections.flatMap(\.items).isEmpty)
    }

    // MARK: - Overdue

    @Test func showOverdue_includesPastPendingEvents() throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let med = Medication(date: pastDate, pet: pet, name: "Overdue Med", dosage: "10mg", frequency: "8h")
        context.insert(med)
        try context.save()

        let vm = makeVM()
        vm.showOverdue = true
        let allItems = vm.sections.flatMap(\.items)
        #expect(allItems.contains(where: { ($0 as? Medication)?.name == "Overdue Med" }))
    }
}

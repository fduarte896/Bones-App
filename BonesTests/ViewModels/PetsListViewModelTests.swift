import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.viewModels))
struct PetsListViewModelTests {
    let context: ModelContext
    let viewModel: PetsListViewModel

    init() throws {
        context = try makeContext()
        viewModel = PetsListViewModel(context: context)
    }

    @Test func init_emptyDatabase_noPets() {
        #expect(viewModel.pets.isEmpty)
    }

    @Test func addPet_insertsAndFetches() throws {
        try viewModel.addPet(name: "Luna")
        #expect(viewModel.pets.count == 1)
        let pet = try #require(viewModel.pets.first, "Expected at least one pet after insert")
        #expect(pet.name == "Luna")
    }

    @Test func addPet_sortsByName() throws {
        try viewModel.addPet(name: "Zoe")
        try viewModel.addPet(name: "Ana")
        #expect(viewModel.pets.map(\.name) == ["Ana", "Zoe"])
    }

    @Test func addPet_multipleNames_allPresent() throws {
        try viewModel.addPet(name: "Luna")
        try viewModel.addPet(name: "Max")
        try viewModel.addPet(name: "Coco")
        #expect(viewModel.pets.count == 3)
    }

    @Test func delete_removesCorrectPet() throws {
        try viewModel.addPet(name: "Luna")
        try viewModel.addPet(name: "Max")
        try viewModel.delete(at: IndexSet(integer: 0))
        #expect(viewModel.pets.count == 1)
        #expect(viewModel.pets.first?.name == "Max")
    }

    @Test func fetchPets_afterExternalInsert() throws {
        let pet = Pet(name: "External")
        context.insert(pet)
        try context.save()
        viewModel.fetchPets()
        #expect(viewModel.pets.count == 1)
        #expect(viewModel.pets.first?.name == "External")
    }

    @Test func updateContext_refreshesPets() throws {
        try viewModel.addPet(name: "Luna")
        #expect(viewModel.pets.count == 1)

        // Create a new context with a different pet
        let newContext = try makeContext()
        let pet = Pet(name: "Max")
        newContext.insert(pet)
        try newContext.save()

        viewModel.updateContext(newContext)
        #expect(viewModel.pets.count == 1)
        #expect(viewModel.pets.first?.name == "Max")
    }
}

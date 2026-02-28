//
//  AddPetTests.swift
//  BonesTests
//
//  Created by Codex on 26/02/2026.
//

import Testing
import SwiftData
@testable import Bones

@MainActor
struct AddPetTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            Grooming.self,
            WeightEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test
    func addPet_insertsAndFetches() throws {
        let context = try makeContext()
        let viewModel = PetsListViewModel(context: context)

        try viewModel.addPet(name: "Luna")

        #expect(viewModel.pets.count == 1)
        #expect(viewModel.pets.first?.name == "Luna")
    }

    @Test
    func addPet_sortsByName() throws {
        let context = try makeContext()
        let viewModel = PetsListViewModel(context: context)

        try viewModel.addPet(name: "Zoe")
        try viewModel.addPet(name: "Ana")

        #expect(viewModel.pets.map(\.name) == ["Ana", "Zoe"])
    }
}

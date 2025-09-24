//
//  BonesAppTests.swift
//  BonesAppTests
//
//  Created by Felipe Duarte on 30/07/25.
//
import Testing
import XCTest
@testable import Bones
import SwiftData


@MainActor
final class PetDetailViewModelTests: XCTestCase {
    
    var context: ModelContext!
    var pet: Pet!
    var vm: PetDetailViewModel!
    
    override func setUpWithError() throws {
        // In-memory container para que nada persista en disco
        let container = try ModelContainer(for: Pet.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        context = container.mainContext
        
        pet = Pet(name: "Loki", species: .dog, breed: "Husky",
                  birthDate: .now, sex: .male, color: "White")
        context.insert(pet)
        
        vm = PetDetailViewModel(petID: pet.id)
        vm.inject(context: context)
    }
    
    func testToggleCompletedSetsDate() throws {
        // 1. Creamos un evento
        let m = Medication(date: .now, pet: pet,
                           name: "Bravecto", dosage: "10 mg", frequency: "SID")
        context.insert(m)
        try context.save()
        
        // 2. Ejecutamos
        vm.toggleCompleted(m)
        
        // 3. Comprobamos
        XCTAssertTrue(m.isCompleted)
        XCTAssertNotNil(m.completedAt)
    }
}

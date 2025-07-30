//
//  Pet.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import Foundation
import SwiftData
import SwiftUI


// MARK: - Pet
@Model
class Pet {
    @Attribute(.unique) var id: UUID
    var name: String
    var species: Species
    var breed: String?
    var birthDate: Date?
    var sex: Sex
    var color: String?
    var photoData: Data?
    var notes: String?

    // Relación inversa; cada evento tiene var pet: Pet?
    @Relationship(deleteRule: .cascade, inverse: \Medication.pet)  var medications: [Medication] = []
    @Relationship(deleteRule: .cascade, inverse: \Vaccine.pet)     var vaccines: [Vaccine] = []
    @Relationship(deleteRule: .cascade, inverse: \Deworming.pet)   var dewormings: [Deworming] = []
    @Relationship(deleteRule: .cascade, inverse: \Grooming.pet)    var groomings: [Grooming] = []
    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet) var weights: [WeightEntry] = []

    init(name: String,
         species: Species = .dog,
         breed: String? = nil,
         birthDate: Date? = nil,
         sex: Sex = .unknown,
         color: String? = nil,
         photoData: Data? = nil,
         notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.breed = breed
        self.birthDate = birthDate
        self.sex = sex
        self.color = color
        self.photoData = photoData
        self.notes = notes
    }
}

enum Species: String, Codable, CaseIterable {
    case dog, cat
}

enum Sex: String, Codable, CaseIterable {
    case male, female, unknown
}

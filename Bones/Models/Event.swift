//
//  Event.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Campos comunes
protocol BasicEvent : PersistentModel {
    var id: UUID { get set }
    var date: Date { get set }
    var title: String { get set }
    var notes: String? { get set }
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var isRecurring: Bool { get set }
    var rrule: String? { get set }
    var pet: Pet? { get set }
}

extension BasicEvent {
    var displayName: String {
        switch self {
        case let vac as Vaccine:      return vac.vaccineName
        case let dew as Deworming:    return (dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación")
        case let w   as WeightEntry:  return String(format: "Peso: %.1f kg", w.weightKg)
        default:                      return title
        }
    }
    
    var displayType: String {
        switch self {
        case is Vaccine:      return "Vacuna"
        case is Deworming:    return "Desparasitación"
        case is WeightEntry:  return "Registro de peso"
        default:              return ""
        }
    }
}



// MARK: - Vaccine
@Model
class Vaccine: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Vacuna"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    // específicos
    var vaccineName: String
    var manufacturer: String?

    // Foto de la prescripción
    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?
    
    init(date: Date,
         pet: Pet,
         vaccineName: String,
         manufacturer: String? = nil,
         notes: String? = nil,
         prescriptionImageData: Data? = nil) {
        self.date = date
        self.pet = pet
        self.vaccineName = vaccineName
        self.manufacturer = manufacturer
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
    }
}

// MARK: - Deworming
@Model
class Deworming: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Desparasitación"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    // Identificador estable de serie (todas las dosis repetidas comparten este UUID)
    var seriesID: UUID?

    // Foto de la prescripción
    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?
    
    init(date: Date,
         pet: Pet,
         notes: String? = nil,
         prescriptionImageData: Data? = nil,
         seriesID: UUID? = nil) {
        self.date = date
        self.pet = pet
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
        self.seriesID = seriesID
    }
}

// MARK: - WeightEntry
@Model
class WeightEntry: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Peso"
    var notes: String?
    var isCompleted: Bool = true   // peso se registra y queda "completado"
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?
    var completedAt: Date?

    var weightKg: Double

    init(date: Date, pet: Pet, weightKg: Double, notes: String? = nil) {
        self.date = date
        self.pet = pet
        self.weightKg = weightKg
        self.notes = notes
    }
}

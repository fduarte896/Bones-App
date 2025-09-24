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
        case let med as Medication:   return med.name
        case let vac as Vaccine:      return vac.vaccineName
        case let dew as Deworming:    return (dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación")
        case let g   as Grooming:     return (g.notes?.isEmpty == false ? g.notes! : "Cita de grooming")
        case let w   as WeightEntry:  return String(format: "Peso: %.1f kg", w.weightKg)
        default:                      return title
        }
    }
    
    var displayType: String {
        switch self {
        case is Medication:   return "Medicamento"
        case is Vaccine:      return "Vacuna"
        case is Deworming:    return "Desparasitación"
        case is Grooming:     return "Grooming"
        case is WeightEntry:  return "Registro de peso"
        default:              return ""
        }
    }
}



// MARK: - Medication
@Model
class Medication: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Medication"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    // específicos
    var name: String
    var dosage: String
    var frequency: String

    // Foto de la prescripción
    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?
    
    init(date: Date,
         pet: Pet,
         name: String,
         dosage: String,
         frequency: String,
         notes: String? = nil,
         prescriptionImageData: Data? = nil) {
        self.date = date
        self.pet = pet
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
    }
}

// MARK: - Vaccine
@Model
class Vaccine: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Vaccine"
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
    var title: String = "Deworming"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    // Foto de la prescripción
    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?
    
    init(date: Date,
         pet: Pet,
         notes: String? = nil,
         prescriptionImageData: Data? = nil) {
        self.date = date
        self.pet = pet
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
    }
}

// MARK: - Grooming
@Model
class Grooming: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Grooming"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    var location: String?
    var completedAt: Date?

    init(date: Date, pet: Pet, location: String? = nil, notes: String? = nil) {
        self.date = date
        self.pet = pet
        self.location = location
        self.notes = notes
    }
}

// MARK: - WeightEntry
@Model
class WeightEntry: BasicEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Weight"
    var notes: String?
    var isCompleted: Bool = true   // peso se registra y queda “completado”
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

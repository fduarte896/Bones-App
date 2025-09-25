// DoseSeries.swift
import Foundation
import SwiftData

enum DoseSeries {
    // Extrae el "nombre base" quitando el sufijo " (dosis X/Y)" si existe
    static func splitDoseBase(from name: String) -> String {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return name
        }
        let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        return base
    }
    
    // Separa "Nombre (dosis X/Y)" -> (base: "Nombre", dose: "Dosis X/Y")
    static func splitDose(from name: String) -> (base: String, dose: String?) {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1) // "("
        let closingParenIndex = name.index(before: name.endIndex)            // ")"
        guard closingParenIndex > openParenIndex else { return (name, nil) }
        let contentStart = name.index(after: openParenIndex)
        let inside = String(name[contentStart..<closingParenIndex]) // "dosis X/Y"
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
    
    // Normaliza notas para comparar series de desparasitación
    static func normalizeNotes(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    static func futureMedications(from med: Medication, in context: ModelContext) -> [Medication] {
        guard let petID = med.pet?.id else { return [med] }
        let base = splitDoseBase(from: med.name)
        let start = med.date
        let predicate = #Predicate<Medication> { m in
            m.pet?.id == petID && m.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        return fetched.filter { splitDoseBase(from: $0.name) == base }
    }
    
    static func futureVaccines(from vac: Vaccine, in context: ModelContext) -> [Vaccine] {
        guard let petID = vac.pet?.id else { return [vac] }
        let base = splitDoseBase(from: vac.vaccineName)
        let start = vac.date
        let predicate = #Predicate<Vaccine> { v in
            v.pet?.id == petID && v.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: predicate))) ?? []
        return fetched.filter { splitDoseBase(from: $0.vaccineName) == base }
    }
    
    static func futureDewormings(from dew: Deworming, in context: ModelContext) -> [Deworming] {
        guard let petID = dew.pet?.id else { return [dew] }
        let baseNotes = normalizeNotes(dew.notes)
        let start = dew.date
        let predicate = #Predicate<Deworming> { d in
            d.pet?.id == petID && d.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))) ?? []
        return fetched.filter { normalizeNotes($0.notes) == baseNotes }
    }
}

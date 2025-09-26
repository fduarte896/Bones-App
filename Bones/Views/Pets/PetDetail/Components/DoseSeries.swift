//
//  DoseSeries.swift
//  Bones
//
//  Extrae la lógica común de series (base de dosis y búsqueda de futuras)
//

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
    
    // Extrae números X/Y desde el nombre "Nombre (dosis X/Y)"
    // Devuelve (current: X?, total: Y?)
    static func parseDoseNumbers(from name: String) -> (current: Int?, total: Int?) {
        let parsed = splitDose(from: name)
        guard let doseText = parsed.dose else { return (nil, nil) }
        // Busca dígitos en el string "Dosis X/Y"
        let components = doseText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                  .filter { !$0.isEmpty }
        let current = components.indices.contains(0) ? Int(components[0]) : nil
        let total   = components.indices.contains(1) ? Int(components[1]) : nil
        return (current, total)
    }
    
    // Normaliza notas para comparar series de desparasitación
    static func normalizeNotes(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // Futuras del mismo medicamento (misma mascota, mismo "base", fecha >= actual)
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
    
    // Futuras del mismo esquema de vacuna
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
    
    // Determina si una vacuna es "de refuerzo" comparando con la anterior del mismo esquema
    // Usa un umbral de ~10 meses para evitar confundir refuerzos con dosis del esquema inicial.
    static func isBooster(_ vac: Vaccine, among all: [Vaccine], thresholdDays: Int = 300) -> Bool {
        guard let petID = vac.pet?.id else { return false }
        let base = splitDoseBase(from: vac.vaccineName)
        let siblings = all
            .filter { $0.pet?.id == petID && splitDoseBase(from: $0.vaccineName) == base }
            .sorted { $0.date < $1.date }
        guard let idx = siblings.firstIndex(where: { $0.id == vac.id }), idx > 0 else { return false }
        let previous = siblings[idx - 1]
        let days = vac.date.timeIntervalSince(previous.date) / (24 * 3600)
        return days >= Double(thresholdDays)
    }
    
    // Futuras desparasitaciones: fetch único y filtrado en memoria
    // Prioridad: seriesID > rrule > notas normalizadas
    static func futureDewormings(from dew: Deworming, in context: ModelContext) -> [Deworming] {
        guard let petID = dew.pet?.id else { return [dew] }
        let start = dew.date
        
        // Trae todas las desparasitaciones de esa mascota en/tras la fecha
        let basePredicate = #Predicate<Deworming> { d in
            d.pet?.id == petID && d.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: basePredicate))) ?? []
        
        if let sid = dew.seriesID {
            let related = fetched.filter { $0.seriesID == sid }
            return related.isEmpty ? [dew] : related
        }
        if let rule = dew.rrule, !rule.isEmpty {
            let related = fetched.filter { $0.rrule == rule }
            return related.isEmpty ? [dew] : related
        }
        let baseNotes = normalizeNotes(dew.notes)
        let related = fetched.filter { normalizeNotes($0.notes) == baseNotes }
        return related.isEmpty ? [dew] : related
    }
}


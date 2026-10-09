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

//
//  AIEngineImpl.swift
//  Bones
//
//  Motor de IA (100% on‑device). Esta versión expone métodos síncronos
//  con heurísticas locales para no tocar tu UI todavía. En el siguiente
//  paso, conectaremos FoundationModels con métodos async equivalentes.
//

import Foundation

actor AIEngine {
    static let shared = AIEngine()

    // MARK: - Parseo rápido por texto (versión síncrona actual de tu UI)
    // Heurística local que funciona hoy. En el siguiente paso
    // añadiremos la variante async con FoundationModels y
    // migraremos tu UI a async/await.
    func parseQuickAdd(text: String) -> QuickAddParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return QuickAddParseResult(events: [], warnings: ["Texto vacío"])
        }

        let lower = trimmed.lowercased()

        // Detectar tipo básico por palabras clave
        let kind: ProposedEventKind = {
            if lower.contains("vacuna") || lower.contains("rabia") || lower.contains("moquillo") {
                return .vaccine
            }
            if lower.contains("desparas") || lower.contains("drontal") || lower.contains("endogard") || lower.contains("panacur") || lower.contains("milbemax") {
                return .deworming
            }
            if lower.contains("groom") || lower.contains("baño") || lower.contains("corte") {
                return .grooming
            }
            if lower.contains("peso") || lower.contains("kg") || lower.contains("lb") {
                return .weight
            }
            return .medication
        }()

        // Nombre base: primera palabra “fuerte” o el texto completo saneado
        let baseName: String = {
            // Intenta extraer algo tipo “amoxicilina”, “rabia”, etc.
            let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            if let first = tokens.first {
                return first.capitalized
            }
            return trimmed
        }()

        // Dosis (número + unidad)
        let dosage: String? = {
            // Busca “250 mg”, “20 ml”, “0.5 mg”, etc.
            let pattern = #"(\d+([.,]\d+)?)\s?(mg|ml|mcg|g|ug|μg)"#
            if let range = lower.range(of: pattern, options: .regularExpression) {
                return String(lower[range])
            }
            return nil
        }()

        // Frecuencia “cada X h/días/semanas/meses” o “cada día/semana/mes”
        let frequency: String? = {
            let patterns = [
                #"cada\s+\d+\s*h"#, #"cada\s+\d+\s*hora"#, #"cada\s+\d+\s*horas"#,
                #"cada\s+\d+\s*d(í|i)as"#, #"cada\s+d(í|i)a"#,
                #"cada\s+\d+\s*semanas"#, #"cada\s*semana"#,
                #"cada\s+\d+\s*mes(es)?"#, #"cada\s*mes"#
            ]
            for p in patterns {
                if let range = lower.range(of: p, options: .regularExpression) {
                    return String(lower[range])
                        .replacingOccurrences(of: "  ", with: " ")
                }
            }
            return nil
        }()

        // Fecha/hora: heurística mínima (si no, ahora + 1h)
        let date: Date = {
            let now = Date()
            // “mañana hh:mm” o “mañana 6pm”
            if lower.contains("mañana") {
                if let hour = Self.extractHour(from: lower) {
                    return Calendar.current.date(byAdding: .day, value: 1, to: Self.date(atHour: hour)) ?? now.addingTimeInterval(3600)
                }
                return Calendar.current.date(byAdding: .day, value: 1, to: now.addingTimeInterval(3600)) ?? now.addingTimeInterval(3600)
            }
            // “hoy hh:mm”
            if lower.contains("hoy") {
                if let hour = Self.extractHour(from: lower) {
                    return Self.date(atHour: hour)
                }
                return now.addingTimeInterval(3600)
            }
            // “20/10 a las 10:00”
            if let d = Self.extractDayMonthHour(from: lower) {
                return d
            }
            return now.addingTimeInterval(3600)
        }()

        let fullName = baseName
        let event = ProposedEvent(kind: kind,
                                  baseName: baseName,
                                  fullName: fullName,
                                  date: date,
                                  dosage: dosage,
                                  frequency: frequency,
                                  notes: nil,
                                  manufacturer: nil)
        return QuickAddParseResult(events: [event], warnings: [])
    }

    // MARK: - Sugerencia de series (versión síncrona actual de tu UI)
    func recommendSeries(for kind: ProposedEventKind,
                         baseName: String,
                         start: Date,
                         dosage: String?,
                         hoursInterval: Int?,
                         totalDoses: Int?) -> [DatedSuggestion] {
        var results: [DatedSuggestion] = [DatedSuggestion(date: start)]
        let cal = Calendar.current

        switch kind {
        case .medication:
            // Si ya tenemos intervalo en horas, úsalo; si no, 8h por defecto.
            let stepHours = hoursInterval ?? 8
            // Si nos dieron totalDoses, respétalo; si no, 3 días aproximados.
            let total: Int = totalDoses ?? max(2, Int((3 * 24) / max(1, stepHours)))
            var current = start
            for _ in 1..<total {
                current = cal.date(byAdding: .hour, value: stepHours, to: current) ?? current
                results.append(DatedSuggestion(date: current))
            }

        case .vaccine:
            // Esquema típico: 3 dosis separadas por 3 semanas.
            let spacingWeeks = 3
            var current = start
            for _ in 1..<3 {
                current = cal.date(byAdding: .day, value: spacingWeeks * 7, to: current) ?? current
                results.append(DatedSuggestion(date: current))
            }
            // Nota: el refuerzo anual lo manejará tu UI (o lo sugeriremos luego con FM).

        default:
            // No generamos series para los demás tipos aquí.
            break
        }
        return results
    }

    // MARK: - Extracción desde imagen (placeholder síncrono)
    func extractFromPrescription(imageData: Data) -> PrescriptionExtractionResult {
        // Placeholder local: sin OCR. Devolver baja confianza.
        return PrescriptionExtractionResult(kind: nil,
                                            baseName: nil,
                                            fullName: nil,
                                            dosage: nil,
                                            frequency: nil,
                                            date: nil,
                                            manufacturer: nil,
                                            notes: nil,
                                            confidence: 0.0)
    }
}

// MARK: - Helpers de fecha/parseo locales (heurísticos)
private extension AIEngine {
    static func extractHour(from lower: String) -> Int? {
        // Busca “6pm”, “18:00”, “6:30”, “6 pm”
        // 1) hh:mm
        if let range = lower.range(of: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#, options: .regularExpression) {
            let comps = lower[range].split(separator: ":")
            if let h = Int(comps[0]) { return h }
        }
        // 2) hh(am|pm)
        if let range = lower.range(of: #"\b(1[0-2]|0?[1-9])\s?(am|pm)\b"#, options: .regularExpression) {
            let s = String(lower[range])
            let parts = s.split(separator: " ")
            if let raw = parts.first, var h = Int(raw) {
                if s.contains("pm") && h < 12 { h += 12 }
                if s.contains("am") && h == 12 { h = 0 }
                return h
            }
        }
        return nil
    }

    static func date(atHour hour: Int) -> Date {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = hour
        comp.minute = 0
        return Calendar.current.date(from: comp) ?? Date()
    }

    static func extractDayMonthHour(from lower: String) -> Date? {
        // Formato simple “dd/mm hh:mm” o “dd/mm a las hh:mm”
        let pattern = #"\b([0-3]?\d)/([01]?\d).{0,6}([01]?\d|2[0-3]):([0-5]\d)\b"#
        guard let range = lower.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(lower[range])

        // Extrae números
        let numbers = match
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        // Esperado: [dd, mm, hh, mm]
        guard numbers.count >= 4 else { return nil }
        let dd = numbers[0], mm = numbers[1], hh = numbers[2], mi = numbers[3]

        var comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        comp.day = dd
        comp.month = mm
        comp.hour = hh
        comp.minute = mi
        return Calendar.current.date(from: comp)
    }
}

// MARK: - (Siguiente paso) Métodos async con FoundationModels
// En el próximo cambio migraremos tu UI a async y activaremos estas rutas.
// Mantendremos 100% on‑device (sin PCC) y structured output para ProposedEvent.
/*
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18, *)
extension AIEngine {
    func parseQuickAddWithFM(text: String) async throws -> QuickAddParseResult {
        // 1) Seleccionar modelo on‑device
        // 2) Prompt + structured output → ProposedEvent / QuickAddParseResult
        // 3) Devolver resultado
    }

    func recommendSeriesWithFM(for kind: ProposedEventKind,
                               baseName: String,
                               start: Date,
                               dosage: String?,
                               hoursInterval: Int?,
                               totalDoses: Int?) async throws -> [DatedSuggestion] {
        // Similar: pedir fechas sugeridas en JSON
    }

    func extractFromPrescriptionWithFM(imageData: Data) async throws -> PrescriptionExtractionResult {
        // Multimodal: imagen → JSON con campos
    }
}
#endif
*/

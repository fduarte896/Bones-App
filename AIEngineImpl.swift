//
//  AIEngineImpl.swift
//  Bones
//
//  Motor de IA híbrido:
//  - iOS 18+: intenta usar FoundationModels (cuando esté disponible y permitido)
//  - iOS < 18 o si falla: cae a la heurística local (on‑device, sin red)
//

import Foundation

actor AIEngine {
    static let shared = AIEngine()
    
    struct Config: Sendable {
        // Permite forzar el uso de heurística aunque haya FM (útil para pruebas A/B)
        static let preferFoundationModels: Bool = true
        // Activa logs de diagnóstico
        static let loggingEnabled: Bool = true
        // Habilita/deshabilita TODAS las funciones de IA para builds específicas (p. ej. TestFlight)
        static let aiFeaturesEnabled: Bool = {
            #if TESTFLIGHT
            return false
            #else
            return true
            #endif
        }()
    }
    
    // MARK: - API pública (async con fallback)
    
    // Quick Add por texto
    func parseQuickAdd(text: String) async -> QuickAddParseResult {
        // Bloqueo global de IA (TestFlight u otros)
        guard AIEngine.Config.aiFeaturesEnabled else {
            log("AI disabled by build flag. Returning placeholder result.")
            return QuickAddParseResult(events: [], warnings: ["Función no disponible en esta build"])
        }
        
        // Ruta FoundationModels si está disponible y permitida
        if shouldUseFoundationModels {
            if #available(iOS 18.0, *) {
                do {
                    let result = try await parseQuickAddWithFM(text: text)
                    log("FM parseQuickAdd OK")
                    return result
                } catch {
                    log("FM parseQuickAdd FAILED: \(error). Falling back to heuristic.")
                }
            }
        }
        // Fallback heurístico
        return parseQuickAddHeuristic(text: text)
    }
    
    // Sugerencia de series (medicamentos/vacunas)
    func recommendSeries(for kind: ProposedEventKind,
                         baseName: String,
                         start: Date,
                         dosage: String?,
                         hoursInterval: Int?,
                         totalDoses: Int?) async -> [DatedSuggestion] {
        // Bloqueo global de IA (TestFlight u otros)
        guard AIEngine.Config.aiFeaturesEnabled else {
            log("AI disabled by build flag. Returning empty series.")
            return []
        }
        
        if shouldUseFoundationModels {
            if #available(iOS 18.0, *) {
                do {
                    let result = try await recommendSeriesWithFM(
                        for: kind,
                        baseName: baseName,
                        start: start,
                        dosage: dosage,
                        hoursInterval: hoursInterval,
                        totalDoses: totalDoses
                    )
                    log("FM recommendSeries OK")
                    return result
                } catch {
                    log("FM recommendSeries FAILED: \(error). Falling back to heuristic.")
                }
            }
        }
        return recommendSeriesHeuristic(for: kind,
                                        baseName: baseName,
                                        start: start,
                                        dosage: dosage,
                                        hoursInterval: hoursInterval,
                                        totalDoses: totalDoses)
    }
    
    // Extracción desde imagen (por ahora sigue siendo síncrona/heurística)
    func extractFromPrescription(imageData: Data) -> PrescriptionExtractionResult {
        // Bloqueo global de IA (TestFlight u otros)
        guard AIEngine.Config.aiFeaturesEnabled else {
            log("AI disabled by build flag. Returning placeholder extraction.")
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
    
    // MARK: - Heurística local (lo que ya tenías)
    
    private func parseQuickAddHeuristic(text: String) -> QuickAddParseResult {
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
        
        // Nombre base
        let baseName: String = {
            let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            if let first = tokens.first {
                return first.capitalized
            }
            return trimmed
        }()
        
        // Dosis
        let dosage: String? = {
            let pattern = #"(\d+([.,]\d+)?)\s?(mg|ml|mcg|g|ug|μg)"#
            if let range = lower.range(of: pattern, options: .regularExpression) {
                return String(lower[range])
            }
            return nil
        }()
        
        // Frecuencia “cada …”
        let frequency: String? = {
            let patterns = [
                #"cada\s+\d+\s*h"#, #"cada\s+\d+\s*hora"#, #"cada\s+\d+\s*horas"#,
                #"cada\s+\d+\s*d(í|i)as"#, #"cada\s+d(í|i)a"#,
                #"cada\s+\d+\s*semanas"#, #"cada\s*semana"#,
                #"cada\s+\d+\s*mes(es)?"#, #"cada\s*mes"#
            ]
            for p in patterns {
                if let range = lower.range(of: p, options: .regularExpression) {
                    return String(lower[range]).replacingOccurrences(of: "  ", with: " ")
                }
            }
            return nil
        }()
        
        // Fecha/hora
        let date: Date = {
            let now = Date()
            if lower.contains("mañana") {
                if let hour = Self.extractHour(from: lower) {
                    return Calendar.current.date(byAdding: .day, value: 1, to: Self.date(atHour: hour)) ?? now.addingTimeInterval(3600)
                }
                return Calendar.current.date(byAdding: .day, value: 1, to: now.addingTimeInterval(3600)) ?? now.addingTimeInterval(3600)
            }
            if lower.contains("hoy") {
                if let hour = Self.extractHour(from: lower) {
                    return Self.date(atHour: hour)
                }
                return now.addingTimeInterval(3600)
            }
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
    
    private func recommendSeriesHeuristic(for kind: ProposedEventKind,
                                          baseName: String,
                                          start: Date,
                                          dosage: String?,
                                          hoursInterval: Int?,
                                          totalDoses: Int?) -> [DatedSuggestion] {
        var results: [DatedSuggestion] = [DatedSuggestion(date: start)]
        let cal = Calendar.current
        
        switch kind {
        case .medication:
            let stepHours = hoursInterval ?? 8
            let total: Int = totalDoses ?? max(2, Int((3 * 24) / max(1, stepHours)))
            var current = start
            for _ in 1..<total {
                current = cal.date(byAdding: .hour, value: stepHours, to: current) ?? current
                results.append(DatedSuggestion(date: current))
            }
        case .vaccine:
            let spacingWeeks = 3
            var current = start
            for _ in 1..<3 {
                current = cal.date(byAdding: .day, value: spacingWeeks * 7, to: current) ?? current
                results.append(DatedSuggestion(date: current))
            }
        default:
            break
        }
        return results
    }
    
    // MARK: - Helpers de fecha/parseo locales (heurísticos)
    private static func extractHour(from lower: String) -> Int? {
        if let range = lower.range(of: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#, options: .regularExpression) {
            let comps = lower[range].split(separator: ":")
            if let h = Int(comps[0]) { return h }
        }
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
    
    private static func date(atHour hour: Int) -> Date {
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comp.hour = hour
        comp.minute = 0
        return Calendar.current.date(from: comp) ?? Date()
    }
    
    private static func extractDayMonthHour(from lower: String) -> Date? {
        let pattern = #"\b([0-3]?\d)/([01]?\d).{0,6}([01]?\d|2[0-3]):([0-5]\d)\b"#
        guard let range = lower.range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(lower[range])
        let numbers = match
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        guard numbers.count >= 4 else { return nil }
        let dd = numbers[0], mm = numbers[1], hh = numbers[2], mi = numbers[3]
        
        var comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        comp.day = dd
        comp.month = mm
        comp.hour = hh
        comp.minute = mi
        return Calendar.current.date(from: comp)
    }
    
    // MARK: - Dispatch helpers
    
    private var shouldUseFoundationModels: Bool {
        // Si las funciones de IA están desactivadas globalmente, no usar FM.
        guard AIEngine.Config.aiFeaturesEnabled else { return false }
        guard AIEngine.Config.preferFoundationModels else { return false }
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) { return true }
        #endif
        return false
    }
    
    private func log(_ message: String) {
        guard AIEngine.Config.loggingEnabled else { return }
        print("🤖 AIEngine:", message)
    }
}

// MARK: - FoundationModels (stubs listos para implementar)
// Nota: este bloque solo compila si existe el módulo FoundationModels (iOS 18+).
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, *)
extension AIEngine {
    
    enum FMError: Error {
        case unavailable
        case decodingFailed
        case emptyResponse
    }
    
    // TODO: Implementa aquí la llamada real a FoundationModels con “structured output”
    // que devuelva QuickAddParseResult. Por ahora lanzamos unavailable para forzar fallback.
    func parseQuickAddWithFM(text: String) async throws -> QuickAddParseResult {
        // Ejemplo de esqueleto:
        // 1) Selecciona el modelo on‑device apropiado (texto pequeño/mediano)
        // 2) Prompt claro pidiendo JSON con campos de ProposedEvent
        // 3) Decodifica a QuickAddParseResult con JSONDecoder y devuelve
        throw FMError.unavailable
    }
    
    // TODO: Implementa la ruta FM para sugerir fechas (DatedSuggestion[])
    func recommendSeriesWithFM(for kind: ProposedEventKind,
                               baseName: String,
                               start: Date,
                               dosage: String?,
                               hoursInterval: Int?,
                               totalDoses: Int?) async throws -> [DatedSuggestion] {
        // Semejante a parseQuickAddWithFM: pedir un array de fechas ISO 8601
        throw FMError.unavailable
    }
}
#endif


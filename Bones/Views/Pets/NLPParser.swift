import Foundation
import NaturalLanguage

final class NLPParser {
    // Regex para “dosis”, frecuencias y fechas relativas
    private let doseRegex = try! NSRegularExpression(pattern: #"(?i)\b(dosis|toma)\s*(\d+)(?:/(\d+))?\b"#)
    private let freqRegex = try! NSRegularExpression(pattern: #"(?i)\bcada\s+(\d+)\s*(h|hora|horas|d|día|dias|días|semana|semanas|mes|meses)\b"#)
    private let timeRegex = try! NSRegularExpression(pattern: #"(?i)\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#)
    private let dateInRegex = try! NSRegularExpression(pattern: #"(?i)\ben\s+(\d+)\s*(d(?:ías)?|dias|semanas|mes(?:es)?)\b"#)
    private let weekdayRegex = try! NSRegularExpression(pattern: #"(?i)\b(lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)\b"#)
    private let manufacturerRegex = try! NSRegularExpression(pattern: #"(?i)\b(fabricante|marca)\s*[:\-]?\s*([A-Za-z0-9\-\s]+)"#)
    private let dosageRegex = try! NSRegularExpression(pattern: #"(?i)\b(\d+(?:[.,]\d+)?)\s*(mg|ml|g|mcg|ug)\b"#)
    
    func extractFromOCR(_ text: String, now: Date = Date()) -> PrescriptionExtractionResult {
        var result = PrescriptionExtractionResult(kind: nil, baseName: nil, fullName: nil, dosage: nil, frequency: nil, date: nil, manufacturer: nil, notes: nil, confidence: 0.0)
        
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
                             .replacingOccurrences(of: "  ", with: " ")
        let lower = normalized.lowercased()
        
        // Tipo
        if lower.contains("vacuna") || lower.contains("vacun") || lower.contains("rabia") {
            result.kind = .vaccine
        } else if lower.contains("desparasit") || lower.contains("endogard") || lower.contains("drontal") || lower.contains("panacur") || lower.contains("milbemax") {
            result.kind = .deworming
        } else if lower.contains("mg") || lower.contains("ml") || lower.contains("cada ") || lower.contains("dosis") {
            result.kind = .medication
        }
        
        // Nombre base: primera línea
        if let firstLine = normalized.split(separator: "\n").first {
            result.baseName = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            result.fullName = result.baseName
        }
        
        // Dosis (cantidad)
        if let match = dosageRegex.firstMatch(in: normalized, range: NSRange(location: 0, length: normalized.utf16.count)) {
            let qty = normalized[Range(match.range(at: 1), in: normalized)!]
            let unit = normalized[Range(match.range(at: 2), in: normalized)!]
            result.dosage = "\(qty) \(unit)".replacingOccurrences(of: ",", with: ".")
        }
        
        // Frecuencia “cada X …”
        if let match = freqRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) {
            let val = lower[Range(match.range(at: 1), in: lower)!]
            let unit = lower[Range(match.range(at: 2), in: lower)!]
            let canonical: String
            if unit.hasPrefix("h") || unit.contains("hora") {
                canonical = "cada \(val) h"
            } else if unit.hasPrefix("d") || unit.contains("día") || unit.contains("dias") {
                canonical = (val == "1") ? "cada día" : "cada \(val) días"
            } else if unit.hasPrefix("semana") {
                canonical = (val == "1") ? "cada semana" : "cada \(val) semanas"
            } else {
                canonical = (val == "1") ? "cada mes" : "cada \(val) meses"
            }
            result.frequency = canonical
        }
        
        // Fabricante (vacunas)
        if let match = manufacturerRegex.firstMatch(in: normalized, range: NSRange(location: 0, length: normalized.utf16.count)) {
            let m = normalized[Range(match.range(at: 2), in: normalized)!].trimmingCharacters(in: .whitespacesAndNewlines)
            result.manufacturer = m
        }
        
        // Fecha
        result.date = inferDate(in: normalized, now: now)
        
        // Confianza heurística
        var score = 0.0
        if result.kind != nil { score += 0.25 }
        if result.baseName?.isEmpty == false { score += 0.25 }
        if result.dosage?.isEmpty == false { score += 0.15 }
        if result.frequency?.isEmpty == false { score += 0.15 }
        if result.date != nil { score += 0.2 }
        result.confidence = min(1.0, score)
        return result
    }
    
    func parseQuickAdd(_ text: String, defaultKind: ProposedEventKind? = nil, reference: Date = Date()) -> QuickAddParseResult {
        var events: [ProposedEvent] = []
        var warnings: [String] = []
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return QuickAddParseResult(events: [], warnings: ["Texto vacío"])
        }
        
        let lower = trimmed.lowercased()
        let kind: ProposedEventKind = {
            if lower.contains("vacun") || lower.contains("rabia") { return .vaccine }
            if lower.contains("desparasit") || lower.contains("endogard") || lower.contains("drontal") { return .deworming }
            if lower.contains("baño") || lower.contains("corte") || lower.contains("groom") { return .grooming }
            if lower.contains("peso") || lower.contains("kg") { return .weight }
            return defaultKind ?? .medication
        }()
        
        // Nombre base
        let baseName: String = {
            if let r = trimmed.range(of: "(") {
                return String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            if let r = trimmed.range(of: ",") {
                return String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
        }()
        
        let date = inferDate(in: trimmed, now: reference) ?? reference
        let dosage = matchFirst(in: trimmed, regex: dosageRegex)
        let frequency = matchFrequency(in: trimmed)
        
        let event = ProposedEvent(kind: kind,
                                  baseName: baseName,
                                  fullName: baseName,
                                  date: date,
                                  dosage: dosage,
                                  frequency: frequency,
                                  notes: nil,
                                  manufacturer: nil)
        events.append(event)
        return QuickAddParseResult(events: events, warnings: warnings)
    }
    
    // MARK: - Helpers
    private func matchFirst(in text: String, regex: NSRegularExpression) -> String? {
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else { return nil }
        return String(text[Range(m.range, in: text)!])
    }
    private func matchFrequency(in text: String) -> String? {
        let lower = text.lowercased()
        guard let match = freqRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) else { return nil }
        let val = lower[Range(match.range(at: 1), in: lower)!]
        let unit = lower[Range(match.range(at: 2), in: lower)!]
        if unit.hasPrefix("h") || unit.contains("hora") { return "cada \(val) h" }
        if unit.hasPrefix("d") || unit.contains("día") || unit.contains("dias") { return (val == "1") ? "cada día" : "cada \(val) días" }
        if unit.hasPrefix("semana") { return (val == "1") ? "cada semana" : "cada \(val) semanas" }
        return (val == "1") ? "cada mes" : "cada \(val) meses"
    }
    
    private func inferDate(in text: String, now: Date) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        
        if lower.contains("hoy") { return now }
        if lower.contains("mañana") || lower.contains("manana") {
            return cal.date(byAdding: .day, value: 1, to: now)
        }
        if let m = dateInRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) {
            let valStr = lower[Range(m.range(at: 1), in: lower)!]
            let unit = lower[Range(m.range(at: 2), in: lower)!]
            let val = Int(valStr) ?? 0
            if unit.hasPrefix("d") { return cal.date(byAdding: .day, value: val, to: now) }
            if unit.hasPrefix("semana") { return cal.date(byAdding: .day, value: 7*val, to: now) }
            return cal.date(byAdding: .month, value: val, to: now)
        }
        if let m = weekdayRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) {
            let dayName = lower[Range(m.range(at: 1), in: lower)!]
            let weekdayMap: [String: Int] = [
                "domingo": 1, "lunes": 2, "martes": 3, "miércoles": 4, "miercoles": 4,
                "jueves": 5, "viernes": 6, "sábado": 7, "sabado": 7
            ]
            if let target = weekdayMap[String(dayName)] {
                var date = next(weekday: target, from: now) ?? now
                if let time = inferTime(in: lower) {
                    date = cal.date(bySettingHour: time.h, minute: time.m, second: 0, of: date) ?? date
                }
                return date
            }
        }
        if let t = inferTime(in: lower) {
            return cal.date(bySettingHour: t.h, minute: t.m, second: 0, of: now)
        }
        return nil
    }
    private func inferTime(in text: String) -> (h: Int, m: Int)? {
        guard let m = timeRegex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else { return nil }
        let hStr = text[Range(m.range(at: 1), in: text)!]
        let minStr = Range(m.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
        let ampm = Range(m.range(at: 3), in: text).map { String(text[$0]).lowercased() }
        var h = Int(hStr) ?? 0
        if let ampm {
            if ampm == "pm", h < 12 { h += 12 }
            if ampm == "am", h == 12 { h = 0 }
        }
        return (h, minStr)
    }
    private func next(weekday: Int, from: Date) -> Date? {
        var comps = DateComponents()
        comps.weekday = weekday
        return Calendar.current.nextDate(after: from, matching: comps, matchingPolicy: .nextTime)
    }
}

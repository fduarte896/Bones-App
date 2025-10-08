import Foundation
import NaturalLanguage

final class NLPParser {
    // Regex para “dosis”, frecuencias y fechas/horas
    private let doseRegex = try! NSRegularExpression(pattern: #"(?i)\b(dosis|toma)\s*(\d+)(?:/(\d+))?\b"#)
    private let freqRegex = try! NSRegularExpression(pattern: #"(?i)\bcada\s+(\d+)\s*(h|hora|horas|d|día|dias|días|semana|semanas|mes|meses)\b"#)
    private let timeRegex = try! NSRegularExpression(pattern: #"(?i)\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#)
    private let dateInRegex = try! NSRegularExpression(pattern: #"(?i)\ben\s+(\d+)\s*(d(?:ías)?|dias|semanas|mes(?:es)?)\b"#)
    private let weekdayRegex = try! NSRegularExpression(pattern: #"(?i)\b(lunes|martes|miércoles|miercoles|jueves|viernes|sábado|sabado|domingo)\b"#)
    private let manufacturerRegex = try! NSRegularExpression(pattern: #"(?i)\b(fabricante|marca)\s*[:\-]?\s*([A-Za-z0-9\-\s]+)"#)
    private let dosageRegex = try! NSRegularExpression(pattern: #"(?i)\b(\d+(?:[.,]\d+)?)\s*(mg|ml|g|mcg|ug)\b"#)
    
    // Palabras clave de fecha (para recortar nombre)
    private let dateKeywords: [String] = ["hoy", "mañana", "manana", "en ", "lunes", "martes", "miércoles", "miercoles", "jueves", "viernes", "sábado", "sabado", "domingo"]
    
    // MARK: - OCR → extracción
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
        
        // Dosis (cantidad)
        if let match = dosageRegex.firstMatch(in: normalized, range: NSRange(location: 0, length: normalized.utf16.count)),
           let r1 = Range(match.range(at: 1), in: normalized),
           let r2 = Range(match.range(at: 2), in: normalized) {
            let qty = normalized[r1]
            let unit = normalized[r2]
            result.dosage = "\(qty) \(unit)".replacingOccurrences(of: ",", with: ".")
        }
        
        // Frecuencia “cada X …”
        if let match = freqRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) {
            result.frequency = canonicalFrequency(from: lower, match: match)
        }
        
        // Fabricante (vacunas)
        if let match = manufacturerRegex.firstMatch(in: normalized, range: NSRange(location: 0, length: normalized.utf16.count)),
           let r = Range(match.range(at: 2), in: normalized) {
            result.manufacturer = normalized[r].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fecha
        result.date = inferDateCombining(text: normalized, now: now)
        
        // Nombre base: toma la primera línea y recorta en la primera “ancla”
        if let firstLine = normalized.split(separator: "\n").first {
            let base = cleanBaseName(from: String(firstLine))
            result.baseName = base
            result.fullName = base
        }
        
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
    
    // MARK: - Quick Add por texto
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
        
        // Base name: recorta en la primera “ancla” (dosis/frecuencia/fecha/hora)
        let baseName = cleanBaseName(from: trimmed)
        
        // Fecha combinando día + hora si hay ambos
        let date = inferDateCombining(text: trimmed, now: reference) ?? reference
        
        // Dosis / Frecuencia
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
    
    // MARK: - Helpers de nombre base
    private func cleanBaseName(from original: String) -> String {
        let s = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = s.lowercased()
        var cutPositions: [Int] = []
        
        func addRangeStart(_ r: NSRange?) {
            if let r, r.location != NSNotFound { cutPositions.append(r.location) }
        }
        
        // Posiciones de dosis, frecuencia y hora
        addRangeStart(doseRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count))?.range)
        addRangeStart(freqRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count))?.range)
        addRangeStart(timeRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count))?.range)
        addRangeStart(dateInRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count))?.range)
        addRangeStart(weekdayRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count))?.range)
        
        // Palabras clave simples (“hoy”, “mañana”, “en ”)
        for kw in dateKeywords {
            if let r = lower.range(of: kw) {
                let pos = lower.distance(from: lower.startIndex, to: r.lowerBound)
                cutPositions.append(pos)
            }
        }
        
        // También corta antes de la primera coma si existe
        if let comma = lower.firstIndex(of: ",") {
            let pos = lower.distance(from: lower.startIndex, to: comma)
            cutPositions.append(pos)
        }
        
        let cut = cutPositions.isEmpty ? s.count : max(0, cutPositions.min() ?? s.count)
        let base = String(s.prefix(cut)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si quedó vacío, devolvemos el original (mejor que nada)
        return base.isEmpty ? s : base
    }
    
    // MARK: - Helpers de frecuencia
    private func matchFirst(in text: String, regex: NSRegularExpression) -> String? {
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else { return nil }
        return String(text[Range(m.range, in: text)!])
    }
    private func matchFrequency(in text: String) -> String? {
        let lower = text.lowercased()
        guard let match = freqRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) else { return nil }
        return canonicalFrequency(from: lower, match: match)
    }
    private func canonicalFrequency(from lower: String, match: NSTextCheckingResult) -> String {
        let val = lower[Range(match.range(at: 1), in: lower)!]
        let unit = lower[Range(match.range(at: 2), in: lower)!]
        if unit.hasPrefix("h") || unit.contains("hora") { return "cada \(val) h" }
        if unit.hasPrefix("d") || unit.contains("día") || unit.contains("dias") { return (val == "1") ? "cada día" : "cada \(val) días" }
        if unit.hasPrefix("semana") { return (val == "1") ? "cada semana" : "cada \(val) semanas" }
        return (val == "1") ? "cada mes" : "cada \(val) meses"
    }
    
    // MARK: - Fecha combinando día + hora
    private func inferDateCombining(text: String, now: Date) -> Date? {
        let lower = text.lowercased()
        let cal = Calendar.current
        var date: Date? = nil
        
        // 1) Día relativo “hoy”, “mañana”
        if lower.contains("hoy") {
            date = now
        } else if lower.contains("mañana") || lower.contains("manana") {
            date = cal.date(byAdding: .day, value: 1, to: now)
        }
        
        // 2) “en X días/semanas/meses”
        if let m = dateInRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)),
           let rVal = Range(m.range(at: 1), in: lower),
           let rUnit = Range(m.range(at: 2), in: lower) {
            let val = Int(lower[rVal]) ?? 0
            let unit = String(lower[rUnit])
            let base = date ?? now
            if unit.hasPrefix("d") {
                date = cal.date(byAdding: .day, value: val, to: base)
            } else if unit.hasPrefix("semana") {
                date = cal.date(byAdding: .day, value: 7 * val, to: base)
            } else {
                date = cal.date(byAdding: .month, value: val, to: base)
            }
        }
        
        // 3) Día de la semana
        if let m = weekdayRegex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)),
           let r = Range(m.range(at: 1), in: lower) {
            let dayName = String(lower[r])
            let weekdayMap: [String: Int] = [
                "domingo": 1, "lunes": 2, "martes": 3, "miércoles": 4, "miercoles": 4,
                "jueves": 5, "viernes": 6, "sábado": 7, "sabado": 7
            ]
            if let target = weekdayMap[dayName] {
                let base = date ?? now
                var comps = DateComponents()
                comps.weekday = target
                date = Calendar.current.nextDate(after: base, matching: comps, matchingPolicy: .nextTime)
            }
        }
        
        // 4) Hora (si existe, se aplica sobre el “día” calculado o sobre hoy)
        if let t = inferTime(in: lower) {
            let base = date ?? now
            date = cal.date(bySettingHour: t.h, minute: t.m, second: 0, of: base)
        }
        
        return date
    }
    private func inferTime(in text: String) -> (h: Int, m: Int)? {
        guard let m = timeRegex.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) else { return nil }
        guard let rH = Range(m.range(at: 1), in: text) else { return nil }
        let hStr = String(text[rH])
        let minStr = Range(m.range(at: 2), in: text).flatMap { Int(text[$0]) } ?? 0
        let ampm = Range(m.range(at: 3), in: text).map { String(text[$0]).lowercased() }
        var h = Int(hStr) ?? 0
        if let ampm {
            if ampm == "pm", h < 12 { h += 12 }
            if ampm == "am", h == 12 { h = 0 }
        }
        return (h, minStr)
    }
}

import Foundation

final class ScheduleRecommender {
    struct Rule {
        let offsetsDays: [Int]     // días desde la primera cita
        let boosterMonths: Int?    // refuerzo en meses desde la última
    }
    
    // Reglas iniciales (extensibles)
    private let vaccineRules: [String: Rule] = [
        // “Rabia”: 3 dosis (0, 21, 42 días) + refuerzo anual
        "rabia": Rule(offsetsDays: [0, 21, 42], boosterMonths: 12),
        "moquillo": Rule(offsetsDays: [0, 21, 42], boosterMonths: 12),
        "parvovirus": Rule(offsetsDays: [0, 21, 42], boosterMonths: 12)
    ]
    
    private let medDefaultHours: [String: Int] = [
        "amoxicilina": 8,
        "doxiciclina": 12,
        "omeprazol": 24
    ]
    
    func recommendVaccineSeries(baseName: String, start: Date) -> [ProposedEvent] {
        let key = baseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rule = vaccineRules[key] else {
            return [ProposedEvent(kind: .vaccine, baseName: baseName, fullName: baseName, date: start, dosage: nil, frequency: nil, notes: nil, manufacturer: nil)]
        }
        let cal = Calendar.current
        var events: [ProposedEvent] = []
        for (idx, day) in rule.offsetsDays.enumerated() {
            let date = cal.date(byAdding: .day, value: day, to: start) ?? start
            let full = "\(baseName) (dosis \(idx+1)/\(rule.offsetsDays.count))"
            events.append(ProposedEvent(kind: .vaccine, baseName: baseName, fullName: full, date: date, dosage: nil, frequency: nil, notes: nil, manufacturer: nil))
        }
        if let m = rule.boosterMonths {
            let boosterDate = cal.date(byAdding: .month, value: m, to: events.last?.date ?? start) ?? start
            let full = "\(baseName)"
            events.append(ProposedEvent(kind: .vaccine, baseName: baseName, fullName: full, date: boosterDate, dosage: nil, frequency: "refuerzo", notes: "Refuerzo recomendado", manufacturer: nil))
        }
        return events
    }
    
    func recommendMedicationSeries(baseName: String, start: Date, hoursInterval: Int? = nil, totalDoses: Int = 3, dosage: String? = nil) -> [ProposedEvent] {
        let cal = Calendar.current
        let interval = hoursInterval ?? medDefaultHours[baseName.lowercased()] ?? 8
        var events: [ProposedEvent] = []
        for i in 0..<totalDoses {
            let date = cal.date(byAdding: .hour, value: interval * i, to: start) ?? start
            let full = totalDoses > 1 ? "\(baseName) (dosis \(i+1)/\(totalDoses))" : baseName
            events.append(ProposedEvent(kind: .medication, baseName: baseName, fullName: full, date: date, dosage: dosage, frequency: "cada \(interval) h", notes: nil, manufacturer: nil))
        }
        return events
    }
}

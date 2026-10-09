import Foundation

/// Cada cuánto se repite una vacuna o desparasitación.
///
/// Se guarda en el campo `rrule` con el mismo formato que usaban las versiones
/// anteriores (`FREQ=MONTHLY;INTERVAL=3`), así los datos existentes siguen valiendo.
struct RepeatRule: Hashable, Identifiable {
    enum Unit: String, CaseIterable {
        case days = "DAILY"
        case weeks = "WEEKLY"
        case months = "MONTHLY"
        case years = "YEARLY"

        var calendarComponent: Calendar.Component {
            switch self {
            case .days:   .day
            case .weeks:  .weekOfYear
            case .months: .month
            case .years:  .year
            }
        }
    }

    var value: Int
    var unit: Unit

    var id: String { rrule }

    init(value: Int, unit: Unit) {
        self.value = max(1, value)
        self.unit = unit
    }

    init?(rrule: String) {
        var fields: [String: String] = [:]
        for part in rrule.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            fields[pair[0].uppercased()] = pair[1].uppercased()
        }
        guard let frequency = fields["FREQ"], let unit = Unit(rawValue: frequency) else { return nil }
        self.init(value: fields["INTERVAL"].flatMap(Int.init) ?? 1, unit: unit)
    }

    var rrule: String { "FREQ=\(unit.rawValue);INTERVAL=\(value)" }

    func next(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: unit.calendarComponent, value: value, to: date) ?? date
    }

    /// "Cada 3 meses", "Cada año".
    var label: String {
        switch (unit, value) {
        case (.days, 1):   "Cada día"
        case (.days, _):   "Cada \(value) días"
        case (.weeks, 1):  "Cada semana"
        case (.weeks, _):  "Cada \(value) semanas"
        case (.months, 1): "Cada mes"
        case (.months, _): "Cada \(value) meses"
        case (.years, 1):  "Cada año"
        case (.years, _):  "Cada \(value) años"
        }
    }

    static let presets: [RepeatRule] = [
        RepeatRule(value: 1, unit: .months),
        RepeatRule(value: 2, unit: .months),
        RepeatRule(value: 3, unit: .months),
        RepeatRule(value: 4, unit: .months),
        RepeatRule(value: 6, unit: .months),
        RepeatRule(value: 1, unit: .years),
        RepeatRule(value: 3, unit: .years)
    ]

    static let yearly = RepeatRule(value: 1, unit: .years)
}

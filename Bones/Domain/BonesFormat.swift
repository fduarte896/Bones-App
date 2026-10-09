import Foundation

/// Textos de fechas y cantidades. La interfaz está en español, así que las fechas
/// también, aunque el teléfono esté en otro idioma.
enum BonesFormat {
    static let locale: Locale = {
        let current = Locale.autoupdatingCurrent
        return current.language.languageCode == .spanish ? current : Locale(identifier: "es")
    }()

    /// "9 ago 2026"
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// "9 ago" si es de este año; con año si no.
    static func shortDay(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        } else {
            day(date)
        }
    }

    /// "9,4 kg"
    static func weight(_ kg: Double) -> String {
        "\(number(kg)) kg"
    }

    /// "+0,3 kg"
    static func weightDelta(_ kg: Double) -> String {
        let sign = kg > 0 ? "+" : (kg < 0 ? "−" : "")
        return "\(sign)\(number(abs(kg))) kg"
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// "2 meses", "10 días", "2 años y 3 meses": cuánto tiempo son `days` días.
    static func span(days: Int) -> String {
        let days = abs(days)
        if days < 14 { return plural(days, "día", "días") }
        if days < 56 { return plural(Int((Double(days) / 7).rounded()), "semana", "semanas") }
        let months = Int((Double(days) / 30.44).rounded())
        if months < 24 { return plural(months, "mes", "meses") }
        let years = months / 12
        let rest = months % 12
        let yearsText = plural(years, "año", "años")
        return rest == 0 ? yearsText : "\(yearsText) y \(plural(rest, "mes", "meses"))"
    }

    /// "Hoy", "Ayer", "Hace 2 meses". Para fechas futuras, "En 2 meses".
    static func ago(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = DayMath.days(from: date, to: now, calendar: calendar)
        return switch days {
        case 0:  "Hoy"
        case 1:  "Ayer"
        case -1: "Mañana"
        case ..<0: "En \(span(days: days))"
        default: "Hace \(span(days: days))"
        }
    }

    /// "Toca hoy", "Toca en 2 semanas", "Tocaba hace 10 días", "Al día".
    static func dueText(for status: CareStatus) -> String? {
        switch status {
        case .overdue(1):              "Tocaba ayer"
        case .overdue(let days):       "Tocaba hace \(span(days: days))"
        case .dueSoon(0):              "Toca hoy"
        case .dueSoon(1):              "Toca mañana"
        case .dueSoon(let days):       "Toca en \(span(days: days))"
        case .upToDate(let days):      "Toca en \(span(days: days))"
        case .noNextDate, .unrecorded: nil
        }
    }

    /// "4 años", "8 meses", "3 semanas".
    static func age(from birthDate: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: birthDate, to: now)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        if years >= 1 { return plural(years, "año", "años") }
        if months >= 1 { return plural(months, "mes", "meses") }
        let weeks = max(0, DayMath.days(from: birthDate, to: now, calendar: calendar)) / 7
        return weeks >= 1 ? plural(weeks, "semana", "semanas") : "Recién nacido"
    }

    private static func plural(_ count: Int, _ one: String, _ many: String) -> String {
        "\(count) \(count == 1 ? one : many)"
    }
}

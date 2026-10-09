import Foundation

/// Lo que el usuario va escribiendo en la hoja de registro, antes de guardarlo.
struct RecordDraft: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case vaccine, deworming, weight

        var id: Self { self }

        var label: String {
            switch self {
            case .vaccine:   "Vacuna"
            case .deworming: "Desparasitación"
            case .weight:    "Peso"
            }
        }
    }

    static let weightRangeKg = 0.1...150.0

    var kind: Kind
    /// Nombre de la vacuna o del producto antiparasitario.
    var name = ""
    var dewormingKind: DewormingKind = .internal
    var date: Date = .now
    var repeatRule: RepeatRule?
    var manufacturer = ""
    var notes = ""
    var photoData: Data?
    var weightKg: Double?

    var isValid: Bool {
        switch kind {
        case .vaccine, .deworming:
            name.nilIfBlank != nil
        case .weight:
            weightKg.map(Self.weightRangeKg.contains) ?? false
        }
    }

    /// Una fecha posterior a hoy significa que todavía no se aplicó: se guarda como programada.
    func isPlanned(now: Date = .now, calendar: Calendar = .current) -> Bool {
        kind != .weight && DayMath.days(from: now, to: date, calendar: calendar) > 0
    }

    /// Cuándo tocará de nuevo si se guarda así.
    func nextDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard kind != .weight, !isPlanned(now: now, calendar: calendar), let repeatRule else { return nil }
        return repeatRule.next(after: date, calendar: calendar)
    }
}

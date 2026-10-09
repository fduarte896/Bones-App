import Foundation

enum CareStatus: Hashable {
    /// No hay nada registrado ni programado.
    case unrecorded
    /// Hay historial, pero no se sabe cuándo toca de nuevo.
    case noNextDate
    case upToDate(daysLeft: Int)
    case dueSoon(daysLeft: Int)
    case overdue(daysLate: Int)

    /// Con cuántos días de antelación algo pasa de "al día" a "toca pronto".
    static let soonWindowDays = 30

    init(lastDate: Date?, nextDate: Date?, now: Date, calendar: Calendar) {
        guard let nextDate else {
            self = lastDate == nil ? .unrecorded : .noNextDate
            return
        }
        let days = DayMath.days(from: now, to: nextDate, calendar: calendar)
        self = if days < 0 {
            .overdue(daysLate: -days)
        } else if days <= Self.soonWindowDays {
            .dueSoon(daysLeft: days)
        } else {
            .upToDate(daysLeft: days)
        }
    }

    var needsAttention: Bool {
        switch self {
        case .dueSoon, .overdue: true
        case .unrecorded, .noNextDate, .upToDate: false
        }
    }

    /// Para ordenar: lo vencido primero, luego lo que toca pronto.
    var sortRank: Int {
        switch self {
        case .overdue: 0
        case .dueSoon: 1
        case .upToDate, .noNextDate: 2
        case .unrecorded: 3
        }
    }
}

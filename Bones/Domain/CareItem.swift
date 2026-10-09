import Foundation

/// Resumen de una vacuna o de un tipo de desparasitación: lo último que se aplicó y cuándo toca.
struct CareItem: Identifiable, Hashable {
    let kind: CareKind
    let title: String
    let lastDate: Date?
    /// Con qué se hizo la última vez: el producto o el laboratorio.
    let lastDetail: String?
    let nextDate: Date?
    let nextRecordID: UUID?
    /// La regla de repetición más reciente, para proponerla al volver a registrar.
    let repeatRule: RepeatRule?
    let status: CareStatus

    var id: CareKind { kind }

    init<Record: HealthRecord>(
        kind: CareKind,
        title: String,
        records: [Record],
        detail: (Record) -> String?,
        now: Date,
        calendar: Calendar
    ) {
        let last = records.filter(\.isCompleted).max { $0.date < $1.date }
        // Algo programado para antes de la última aplicación ya quedó atrás: no cuenta como pendiente.
        let next = records
            .filter { record in
                guard !record.isCompleted else { return false }
                guard let last else { return true }
                return DayMath.days(from: last.date, to: record.date, calendar: calendar) > 0
            }
            .min { $0.date < $1.date }
        self.kind = kind
        self.title = title
        self.lastDate = last?.date
        self.lastDetail = last.flatMap(detail)
        self.nextDate = next?.date
        self.nextRecordID = next?.id
        self.repeatRule = (last ?? next)?.repeatRule
        self.status = CareStatus(lastDate: last?.date, nextDate: next?.date, now: now, calendar: calendar)
    }
}

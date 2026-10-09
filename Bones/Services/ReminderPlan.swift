import Foundation

/// Un recordatorio listo para programar. No depende de SwiftData, así puede cruzar actores.
struct ReminderPlan: Hashable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date

    /// Los avisos de una fecha pendiente: uno con antelación y otro el mismo día.
    /// Solo se devuelven los que todavía están en el futuro.
    static func fireDates(due: Date, leadDays: Int, now: Date, calendar: Calendar = .current) -> [Date] {
        let dueMorning = calendar.date(bySettingHour: ReminderDefaults.hour, minute: 0, second: 0, of: due) ?? due
        var dates = [dueMorning]
        if leadDays > 0, let early = calendar.date(byAdding: .day, value: -leadDays, to: dueMorning) {
            dates.insert(early, at: 0)
        }
        return dates.filter { $0 > now }
    }

    static func plans(
        recordID: UUID,
        petName: String,
        subject: String,
        due: Date,
        leadDays: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [ReminderPlan] {
        fireDates(due: due, leadDays: leadDays, now: now, calendar: calendar).map { fireDate in
            let onTheDay = calendar.isDate(fireDate, inSameDayAs: due)
            let when = onTheDay ? "toca hoy" : "toca el \(BonesFormat.shortDay(due, now: fireDate, calendar: calendar))"
            return ReminderPlan(
                identifier: "\(recordID.uuidString)-\(onTheDay ? "due" : "lead")",
                title: petName,
                body: "\(subject) \(when).",
                fireDate: fireDate
            )
        }
    }
}

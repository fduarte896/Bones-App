import Foundation

enum DayMath {
    /// Días de calendario entre dos fechas, ignorando la hora. Negativo si `end` es anterior.
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

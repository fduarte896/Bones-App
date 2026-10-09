import Foundation

struct WeightSummary: Hashable {
    struct Point: Hashable, Identifiable {
        let date: Date
        let kg: Double
        var id: Date { date }
    }

    let latestKg: Double
    let latestDate: Date
    /// Diferencia con la medición anterior, si la hay.
    let deltaKg: Double?
    /// Las últimas mediciones, de la más antigua a la más reciente.
    let recent: [Point]

    init?(entries: [WeightEntry], recentLimit: Int = 12) {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return nil }
        latestKg = latest.weightKg
        latestDate = latest.date
        deltaKg = sorted.count >= 2 ? latest.weightKg - sorted[sorted.count - 2].weightKg : nil
        recent = sorted.suffix(recentLimit).map { Point(date: $0.date, kg: $0.weightKg) }
    }
}

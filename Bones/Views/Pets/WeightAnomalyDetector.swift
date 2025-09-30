import Foundation
import SwiftData

struct WeightAnomalyResult: Sendable {
    let isAnomalous: Bool
    let zScore: Double
    let mean: Double
    let std: Double
}

final class WeightAnomalyDetector {
    // Usa últimas N mediciones para baseline
    func analyze(petID: UUID, context: ModelContext, latestOnly: Bool = true, window: Int = 6, threshold: Double = 2.5) -> WeightAnomalyResult? {
        let all = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let weights = all.filter { $0.pet?.id == petID }
                         .sorted { $0.date > $1.date }
        guard weights.count >= 3 else { return nil }
        
        let latest = weights[0]
        let baseline = Array(weights.dropFirst().prefix(window))
        let values = baseline.map { $0.weightKg }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let std = max(0.0001, sqrt(variance))
        
        let z = (latest.weightKg - mean) / std
        return WeightAnomalyResult(isAnomalous: abs(z) >= threshold, zScore: z, mean: mean, std: std)
    }
}

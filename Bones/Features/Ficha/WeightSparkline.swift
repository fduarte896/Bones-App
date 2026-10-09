import SwiftUI
import Charts

/// La tendencia del peso en pequeño, sin ejes.
struct WeightSparkline: View {
    let points: [WeightSummary.Point]

    private var domain: ClosedRange<Double> {
        let values = points.map(\.kg)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.2, 0.1)
        return (low - padding)...(high + padding)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("Peso", point.kg))
                    .interpolationMethod(.catmullRom)
            }
            if let last = points.last {
                PointMark(x: .value("Fecha", last.date), y: .value("Peso", last.kg))
                    .symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: domain)
        .accessibilityHidden(true)
    }
}

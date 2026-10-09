import SwiftUI
import Charts

struct WeightChart: View {
    let points: [WeightSummary.Point]

    private var domain: ClosedRange<Double> {
        let values = points.map(\.kg)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.25, 0.5)
        return max(0, low - padding)...(high + padding)
    }

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Fecha", point.date), y: .value("Peso", point.kg))
                .interpolationMethod(.catmullRom)
            AreaMark(x: .value("Fecha", point.date),
                     yStart: .value("Base", domain.lowerBound),
                     yEnd: .value("Peso", point.kg))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.tint.opacity(0.12))
            PointMark(x: .value("Fecha", point.date), y: .value("Peso", point.kg))
                .symbolSize(24)
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(BonesFormat.weight(kg))
                    }
                }
            }
        }
        .frame(minHeight: 180)
        .accessibilityLabel("Gráfica de peso")
    }
}

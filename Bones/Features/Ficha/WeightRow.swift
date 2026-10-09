import SwiftUI

struct WeightRow: View {
    let summary: WeightSummary

    private var detail: String {
        var parts = [BonesFormat.ago(summary.latestDate)]
        if let delta = summary.deltaKg, abs(delta) >= 0.05 {
            parts.append(BonesFormat.weightDelta(delta))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(BonesFormat.weight(summary.latestKg))
                    .font(.title3)
                    .bold()
                    .contentTransition(.numericText(value: summary.latestKg))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if summary.recent.count > 1 {
                WeightSparkline(points: summary.recent)
                    .frame(width: 88, height: 36)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

struct VaccineRow: View {
    let item: CareItem

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(item.title)
                    .font(.headline)
                if let lastDate = item.lastDate {
                    // Si no cabe la fecha junto al estado, se queda solo con "Hace 11 meses".
                    ViewThatFits(in: .horizontal) {
                        Text("\(BonesFormat.ago(lastDate)) · \(BonesFormat.shortDay(lastDate))")
                        Text(BonesFormat.ago(lastDate))
                    }
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .changingText(lastDate)
                } else {
                    Text("Sin aplicar todavía")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusBadge(status: item.status)
                .fixedSize()
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}

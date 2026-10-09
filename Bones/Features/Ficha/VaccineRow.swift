import SwiftUI

struct VaccineRow: View {
    let item: CareItem

    private var detail: String {
        guard let lastDate = item.lastDate else {
            return "Sin aplicar todavía"
        }
        return "\(BonesFormat.ago(lastDate)) · \(BonesFormat.shortDay(lastDate))"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(item.title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
            StatusBadge(status: item.status)
        }
        .accessibilityElement(children: .combine)
    }
}

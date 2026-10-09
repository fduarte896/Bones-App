import SwiftUI

/// "Interna · Hace 2 meses · Drontal Plus · 9 ago": la respuesta a "¿hace cuánto y con qué?".
struct DewormingRow: View {
    let item: CareItem
    let kind: DewormingKind

    private var headline: String {
        item.lastDate.map { BonesFormat.ago($0) } ?? "Sin registrar"
    }

    private var detail: String? {
        guard let lastDate = item.lastDate else {
            return BonesFormat.dueText(for: item.status) ?? kind.hint
        }
        return [item.lastDetail, BonesFormat.shortDay(lastDate)].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            Image(systemName: kind.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(kind.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(headline)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(item.lastDate == nil ? .secondary : .primary)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

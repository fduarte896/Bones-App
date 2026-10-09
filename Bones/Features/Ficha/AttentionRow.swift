import SwiftUI

/// Algo vencido o que toca pronto, con el botón para registrarlo ya.
struct AttentionRow: View {
    let item: CareItem
    let onRegister: () -> Void

    private var title: String {
        switch item.kind {
        case .vaccine:             item.title
        case .deworming(let kind): kind.longName
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            Image(systemName: item.status.symbolName)
                .font(.title3)
                .foregroundStyle(item.status.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(title)
                    .font(.headline)
                if let dueText = BonesFormat.dueText(for: item.status) {
                    Text(dueText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Registrar", action: onRegister)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityInputLabels(["Registrar \(title)"])
        }
        .accessibilityElement(children: .combine)
    }
}

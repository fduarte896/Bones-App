import SwiftUI

/// Lo esencial arriba del historial: cuándo fue la última vez, con qué y cuándo toca.
struct CareHistoryHeader: View {
    let item: CareItem

    private var headline: String {
        item.lastDate.map { BonesFormat.ago($0) } ?? "Sin aplicar todavía"
    }

    private var detail: String? {
        guard let lastDate = item.lastDate else { return nil }
        return [item.lastDetail, BonesFormat.day(lastDate)].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(.title)
                .bold()
                .changingText(headline)
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .changingText(detail)
            }
            if let dueText = BonesFormat.dueText(for: item.status) {
                Label {
                    Text(dueText)
                        .changingText(dueText)
                } icon: {
                    Image(systemName: item.status.symbolName)
                        .foregroundStyle(item.status.tint)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(Theme.contentChange, value: item.status)
                }
                .font(.subheadline)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

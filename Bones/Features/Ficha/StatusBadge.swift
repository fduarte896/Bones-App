import SwiftUI

struct StatusBadge: View {
    let status: CareStatus

    var body: some View {
        if let text = status.badgeText {
            Label {
                Text(text)
                    .foregroundStyle(.secondary)
                    .changingText(text)
            } icon: {
                Image(systemName: status.symbolName)
                    .foregroundStyle(status.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(Theme.contentChange, value: status)
            }
            .font(.subheadline)
            .labelStyle(.titleAndIcon)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        StatusBadge(status: .overdue(daysLate: 4))
        StatusBadge(status: .dueSoon(daysLeft: 12))
        StatusBadge(status: .upToDate(daysLeft: 90))
    }
}

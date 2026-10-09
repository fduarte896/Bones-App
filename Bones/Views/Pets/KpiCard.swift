import SwiftUI

struct KpiCard: View {
    let icon: String
    let iconColor: Color
    let pillLabel: String
    let eyebrow: String
    let dateText: String
    let eventName: String
    let date: Date
    let status: HealthStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                StatusPill(status: status, label: pillLabel)
                Spacer(minLength: 0)
            }

            Text(eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
                .textCase(.uppercase)

            Text(dateText)
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(status == .overdue ? Color.bonesOverdue : Color.bonesInk)

            Text(eventName)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.bonesInkSoft)
                .lineLimit(2)

            MiniTimeline(date: date, status: status)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bonesPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.bonesRule, lineWidth: 1)
                )
        )
    }
}

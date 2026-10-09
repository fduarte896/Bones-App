import SwiftUI

struct StatusPill: View {
    let status: HealthStatus
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .background(Capsule().fill(status.color.opacity(0.08)))
        .foregroundStyle(status.color)
    }
}

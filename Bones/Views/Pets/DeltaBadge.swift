import SwiftUI

struct DeltaBadge: View {
    let delta: String
    let trend: WeightTrend

    private var color: Color {
        switch trend {
        case .up:   return .bonesOk
        case .down: return .bonesOverdue
        case .flat: return .bonesInkFaint
        }
    }

    private var iconName: String {
        switch trend {
        case .up:   return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .semibold))
            Text(delta)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

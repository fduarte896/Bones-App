import SwiftUI

struct MiniTimeline: View {
    let date: Date
    let status: HealthStatus

    var body: some View {
        GeometryReader { geo in
            let fraction = fillFraction()
            let barWidth = max(4, geo.size.width * fraction)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(status.color.opacity(0.12))
                    .frame(height: 4)
                Capsule()
                    .fill(status.color.opacity(0.5))
                    .frame(width: barWidth, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(status.color)
                    .frame(width: 3, height: 8)
                    .offset(x: status == .overdue ? 0 : max(0, barWidth - 1.5), y: -2)
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }

    private func fillFraction() -> CGFloat {
        let window: TimeInterval = 14 * 24 * 3600
        let now = Date()
        if status == .overdue {
            return min(CGFloat(abs(date.timeIntervalSince(now)) / window), 1)
        }
        let until = date.timeIntervalSince(now)
        guard until > 0 else { return 1 }
        return max(0, 1 - CGFloat(until / window))
    }
}

import SwiftUI

struct MiniStat: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.bonesInkFaint)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bonesInk)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.bonesInkSoft)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bonesBg)
        )
    }
}

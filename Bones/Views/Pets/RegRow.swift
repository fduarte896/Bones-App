import SwiftUI

struct RegRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let meta: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.bonesBg)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
                .textCase(.uppercase)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bonesInk)
                .lineLimit(1)
            if let meta {
                Text(meta)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.bonesInkSoft)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

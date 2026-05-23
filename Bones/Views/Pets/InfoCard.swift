import SwiftUI

struct InfoCard: View {
    let icon: String
    let title: String
    let primary: String
    let secondary: String?

    private let minHeight: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(primary)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(secondary ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity((secondary?.isEmpty ?? true) ? 0 : 1)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

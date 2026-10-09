import SwiftUI

/// Una entrada del historial.
struct RecordRow: View {
    let title: String
    let subtitle: String
    var notes: String?
    var hasPhoto = false

    var body: some View {
        HStack(spacing: Theme.Spacing.row) {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if hasPhoto {
                Image(systemName: "paperclip")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Tiene foto")
            }
        }
        .contentShape(.rect)
    }
}

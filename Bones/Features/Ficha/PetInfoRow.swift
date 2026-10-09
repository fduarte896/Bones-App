import SwiftUI

/// Foto y datos básicos de la mascota. Al tocarla se abre la edición.
struct PetInfoRow: View {
    let pet: Pet
    let onEdit: () -> Void

    private var facts: String {
        var parts = [pet.species.displayName]
        if let breed = pet.breed?.nilIfBlank { parts.append(breed) }
        return parts.joined(separator: " · ")
    }

    private var details: String? {
        var parts: [String] = []
        if let birthDate = pet.birthDate { parts.append(BonesFormat.age(from: birthDate)) }
        if pet.sex != .unknown { parts.append(pet.sex.displayName) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: Theme.Spacing.row) {
                PetAvatar(pet: pet, size: Theme.AvatarSize.header)
                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                    Text(facts)
                        .foregroundStyle(.primary)
                    if let details {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .bold()
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edita los datos de \(pet.name)")
    }
}

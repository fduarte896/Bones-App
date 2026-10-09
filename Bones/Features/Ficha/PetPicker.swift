import SwiftUI

/// Fila de mascotas para saltar de una ficha a otra. Solo aparece si hay más de una.
struct PetPicker: View {
    let pets: [Pet]
    let selected: Pet
    let onSelect: (Pet) -> Void

    @Namespace private var selection

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(pets) { pet in
                    PetChip(pet: pet, isSelected: pet.id == selected.id, selection: selection) {
                        onSelect(pet)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PetChip: View {
    let pet: Pet
    let isSelected: Bool
    let selection: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                PetAvatar(pet: pet, size: Theme.AvatarSize.chip)
                Text(pet.name)
                    .font(.subheadline)
                    .bold(isSelected)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.tint.quaternary)
                        .matchedGeometryEffect(id: "selection", in: selection)
                } else {
                    Capsule()
                        .fill(.fill.tertiary)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

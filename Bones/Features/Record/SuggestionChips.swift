import SwiftUI

/// Nombres ya usados, para elegir con un toque en vez de escribir.
struct SuggestionChips: View {
    let suggestions: [String]
    let selected: String
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { name in
                    SuggestionChip(name: name, isSelected: isSelected(name)) {
                        onPick(name)
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private func isSelected(_ name: String) -> Bool {
        CareKind.vaccineKey(for: name) == CareKind.vaccineKey(for: selected)
    }
}

private struct SuggestionChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(name, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isSelected ? .accentColor : .secondary)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

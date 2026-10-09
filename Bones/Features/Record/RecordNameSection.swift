import SwiftUI

/// Qué vacuna o qué producto, con sugerencias sacadas del historial.
struct RecordNameSection: View {
    @Binding var draft: RecordDraft
    let isNew: Bool
    let suggestions: [String]
    let onPickSuggestion: (String) -> Void

    var body: some View {
        Section {
            if draft.kind == .deworming {
                Picker("Tipo", selection: $draft.dewormingKind) {
                    ForEach(DewormingKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!isNew)
            }

            TextField(draft.kind == .vaccine ? "Nombre de la vacuna" : "Producto", text: $draft.name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)

            if !suggestions.isEmpty {
                SuggestionChips(suggestions: suggestions, selected: draft.name, onPick: onPickSuggestion)
            }

            if draft.kind == .vaccine {
                TextField("Laboratorio (opcional)", text: $draft.manufacturer)
                    .autocorrectionDisabled()
            }
        } footer: {
            if draft.kind == .deworming {
                Text(draft.dewormingKind.hint)
            }
        }
    }
}

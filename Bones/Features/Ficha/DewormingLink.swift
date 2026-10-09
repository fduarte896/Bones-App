import SwiftUI

/// Con historial, la fila lleva a él; sin nada registrado, abre directamente el registro.
struct DewormingLink: View {
    let pet: Pet
    let kind: DewormingKind
    let summary: PetHealthSummary
    let zoom: Namespace.ID
    let onRegister: () -> Void

    private var item: CareItem {
        kind == .internal ? summary.internalDeworming : summary.externalDeworming
    }

    private var route: CareRoute {
        .care(petID: pet.id, kind: .deworming(kind))
    }

    var body: some View {
        if item.status == .unrecorded {
            Button(action: onRegister) {
                DewormingRow(item: item, kind: kind)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Registra la primera")
        } else {
            NavigationLink(value: route) {
                DewormingRow(item: item, kind: kind)
            }
            .matchedTransitionSource(id: route, in: zoom)
        }
    }
}

import SwiftUI
import SwiftData

/// La pantalla principal: todo lo importante de una mascota, sin tocar nada.
struct PetFichaView: View {
    let pet: Pet
    let pets: [Pet]
    let zoom: Namespace.ID
    @Binding var sheet: RootSheet?
    let onSelect: (Pet) -> Void

    var body: some View {
        let summary = PetHealthSummary(pet: pet)
        let attention = summary.needingAttention

        List {
            if pets.count > 1 {
                Section {
                    PetPicker(pets: pets, selected: pet, onSelect: onSelect)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .listSectionSpacing(.compact)
            }

            Section {
                PetInfoRow(pet: pet, onEdit: editPet)
            }

            if !attention.isEmpty {
                Section("Pendiente") {
                    ForEach(attention) { item in
                        AttentionRow(item: item) { register(fulfilling: item) }
                    }
                }
            }

            Section("Desparasitación") {
                ForEach(DewormingKind.allCases) { kind in
                    DewormingLink(pet: pet, kind: kind, summary: summary, zoom: zoom) {
                        register(.init(pet: pet, kind: .deworming, dewormingKind: kind))
                    }
                }
            }

            Section("Vacunas") {
                ForEach(summary.vaccines) { item in
                    NavigationLink(value: CareRoute.care(petID: pet.id, kind: item.kind)) {
                        VaccineRow(item: item)
                    }
                    .matchedTransitionSource(id: CareRoute.care(petID: pet.id, kind: item.kind), in: zoom)
                }
                Button("Añadir vacuna", systemImage: "plus", action: addVaccine)
            }

            Section("Peso") {
                if let weight = summary.weight {
                    NavigationLink(value: CareRoute.weight(petID: pet.id)) {
                        WeightRow(summary: weight)
                    }
                    .matchedTransitionSource(id: CareRoute.weight(petID: pet.id), in: zoom)
                } else {
                    Button("Registrar peso", systemImage: "plus", action: addWeight)
                }
            }
        }
        .contentMargins(.bottom, 72, for: .scrollContent)
        .animation(Theme.contentChange, value: attention)
        .navigationTitle(pet.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Más", systemImage: "ellipsis") {
                    Button("Editar a \(pet.name)", systemImage: "pencil", action: editPet)
                    Button("Añadir mascota", systemImage: "plus", action: addPet)
                    Divider()
                    Button("Ajustes", systemImage: "gearshape", action: openSettings)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            RegisterButton(action: registerAnything)
        }
    }

    private func register(_ request: RecordRequest) {
        sheet = .record(request)
    }

    private func register(fulfilling item: CareItem) {
        register(.fulfilling(item, for: pet))
    }

    private func registerAnything() {
        register(.init(pet: pet, kind: .deworming))
    }

    private func addVaccine() {
        register(.init(pet: pet, kind: .vaccine))
    }

    private func addWeight() {
        register(.init(pet: pet, kind: .weight))
    }

    private func editPet() {
        sheet = .editPet(pet)
    }

    private func addPet() {
        sheet = .newPet
    }

    private func openSettings() {
        sheet = .settings
    }
}

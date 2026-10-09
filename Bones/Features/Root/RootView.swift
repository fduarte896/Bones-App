import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Pet.name) private var pets: [Pet]
    @AppStorage(AppStorageKey.selectedPetID) private var selectedPetID = ""

    @State private var path: [CareRoute] = []
    @State private var sheet: RootSheet?
    @State private var savedCount = 0
    @Namespace private var zoom

    private var selectedPet: Pet? {
        pets.first { $0.id.uuidString == selectedPetID } ?? pets.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let pet = selectedPet {
                    PetFichaView(pet: pet, pets: pets, zoom: zoom, savedCount: savedCount,
                                 sheet: $sheet, onSelect: select)
                        .transition(.opacity)
                } else {
                    WelcomeView(onAddPet: addPet)
                        .transition(.opacity)
                }
            }
            .animation(Theme.contentChange, value: selectedPet == nil)
            .navigationDestination(for: CareRoute.self) { route in
                CareRouteDestination(route: route, pets: pets, zoom: zoom, onSaved: didSave)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .record(let request):
                RecordSheet(request: request, onSaved: didSave)
            case .newPet:
                PetFormSheet(pet: nil, onSaved: select)
            case .editPet(let pet):
                PetFormSheet(pet: pet, onSaved: select)
            case .settings:
                SettingsView()
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.selection, trigger: selectedPet?.id)
        .onOpenURL(perform: open)
        .task {
            DataSync.afterChange(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { DataSync.afterChange(in: context) }
        }
        .onChange(of: pets.map(\.id)) {
            path.removeAll { route in !pets.contains { $0.id == route.petID } }
        }
    }

    private func addPet() {
        sheet = .newPet
    }

    private func select(_ pet: Pet) {
        guard selectedPetID != pet.id.uuidString else { return }
        // Con "Reducir movimiento" la ficha cambia sin que las filas se deslicen.
        withAnimation(reduceMotion ? nil : Theme.contentChange) {
            selectedPetID = pet.id.uuidString
        }
    }

    private func didSave() {
        savedCount += 1
        DataSync.afterChange(in: context)
    }

    /// El widget abre `bones://events?petId=…&action=add`.
    private func open(_ url: URL) {
        guard url.scheme == "bones" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let petID = items.first { $0.name == "petId" }?.value
        guard let pet = pets.first(where: { $0.id.uuidString == petID }) ?? selectedPet else { return }

        path.removeAll()
        select(pet)
        if items.contains(where: { $0.name == "action" && $0.value == "add" }) {
            sheet = .record(RecordRequest(pet: pet, kind: .vaccine))
        }
    }
}

#Preview("Con mascotas") {
    RootView()
        .modelContainer(PreviewData.container())
        .environment(\.locale, BonesFormat.locale)
}

#Preview("Vacío") {
    RootView()
        .modelContainer(PreviewData.container(seeded: false))
}

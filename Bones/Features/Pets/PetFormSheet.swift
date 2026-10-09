import SwiftUI
import SwiftData

/// Crear una mascota o editar una existente.
struct PetFormSheet: View {
    let pet: Pet?
    let onSaved: (Pet) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PetDraft
    @State private var isConfirmingDelete = false
    @State private var isShowingSaveError = false

    init(pet: Pet?, onSaved: @escaping (Pet) -> Void) {
        self.pet = pet
        self.onSaved = onSaved
        _draft = State(initialValue: pet.map(PetDraft.init(pet:)) ?? PetDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PetPhotoPicker(photoData: $draft.photoData, species: draft.species)
                        .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Nombre", text: $draft.name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    Picker("Especie", selection: $draft.species) {
                        ForEach(Species.allCases) { species in
                            Text(species.displayName).tag(species)
                        }
                    }
                    Picker("Sexo", selection: $draft.sex) {
                        ForEach(Sex.allCases) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }
                }

                Section {
                    TextField("Raza (opcional)", text: $draft.breed)
                    Toggle("Sé su fecha de nacimiento", isOn: $draft.hasBirthDate.animation())
                    if draft.hasBirthDate {
                        DatePicker("Nacimiento", selection: $draft.birthDate, in: ...Date.now,
                                   displayedComponents: .date)
                    }
                }

                if pet != nil {
                    Section {
                        Button("Eliminar mascota", systemImage: "trash", role: .destructive, action: confirmDelete)
                            .confirmationDialog("¿Eliminar a \(draft.name)?", isPresented: $isConfirmingDelete,
                                                titleVisibility: .visible) {
                                Button("Eliminar con todo su historial", role: .destructive, action: delete)
                            } message: {
                                Text("Se borrarán también sus vacunas, desparasitaciones y pesos. No se puede deshacer.")
                            }
                    }
                }
            }
            .navigationTitle(pet == nil ? "Nueva mascota" : "Editar mascota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .alert("No se pudo guardar", isPresented: $isShowingSaveError) {
            } message: {
                Text("Inténtalo de nuevo.")
            }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func save() {
        let target = pet ?? Pet(name: draft.name)
        if pet == nil { context.insert(target) }
        draft.apply(to: target)
        do {
            try context.save()
            DataSync.afterChange(in: context)
            onSaved(target)
            dismiss()
        } catch {
            context.rollback()
            isShowingSaveError = true
        }
    }

    private func delete() {
        guard let pet else { return }
        context.delete(pet)
        do {
            try context.save()
            DataSync.afterChange(in: context)
            dismiss()
        } catch {
            context.rollback()
            isShowingSaveError = true
        }
    }
}

#Preview("Nueva") {
    PetFormSheet(pet: nil, onSaved: { _ in })
        .modelContainer(PreviewData.container(seeded: false))
}

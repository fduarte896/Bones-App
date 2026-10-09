import SwiftUI
import SwiftData

/// La hoja de "Registrar": sirve para anotar algo nuevo, cumplir algo pendiente
/// o corregir una entrada del historial.
struct RecordSheet: View {
    let request: RecordRequest
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allVaccines: [Vaccine]
    @Query private var allDewormings: [Deworming]

    @State private var draft: RecordDraft
    @State private var isShowingSaveError = false
    @State private var isConfirmingDelete = false

    init(request: RecordRequest, onSaved: @escaping () -> Void) {
        self.request = request
        self.onSaved = onSaved
        _draft = State(initialValue: RecordDraft(request: request))
    }

    private var isNew: Bool { !request.isEditing }

    private var title: String {
        isNew || request.applyingToday ? "Registrar" : "Editar"
    }

    private var suggestions: [String] {
        switch draft.kind {
        case .vaccine:
            ProductCatalog.suggestions(
                used: allVaccines.map { ($0.vaccineName, $0.date) },
                defaults: ProductCatalog.defaultVaccines(for: request.pet.species)
            )
        case .deworming:
            ProductCatalog.suggestions(
                used: allDewormings
                    .filter { $0.kind == draft.dewormingKind && !$0.productName.isEmpty }
                    .map { ($0.productName, $0.date) },
                defaults: ProductCatalog.defaultProducts(for: draft.dewormingKind)
            )
        case .weight:
            []
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        Picker("Qué registrar", selection: $draft.kind) {
                            ForEach(RecordDraft.Kind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if draft.kind == .weight {
                    RecordWeightSection(draft: $draft)
                    Section {
                        TextField("Notas", text: $draft.notes, axis: .vertical)
                            .lineLimit(1...5)
                    }
                } else {
                    RecordNameSection(draft: $draft, isNew: isNew, suggestions: suggestions,
                                      onPickSuggestion: pickSuggestion)
                    RecordScheduleSection(draft: $draft)
                    PrescriptionPhotoSection(photoData: $draft.photoData, notes: $draft.notes)
                }

                if !isNew {
                    Section {
                        Button("Eliminar", systemImage: "trash", role: .destructive, action: confirmDelete)
                            .confirmationDialog("¿Eliminar este registro?", isPresented: $isConfirmingDelete,
                                                titleVisibility: .visible) {
                                Button("Eliminar", role: .destructive, action: delete)
                            } message: {
                                Text("No se puede deshacer.")
                            }
                    }
                }
            }
            .animation(.default, value: draft.kind)
            .navigationTitle(title)
            .navigationSubtitle(request.pet.name)
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
            .onChange(of: draft.kind) { _, kind in
                guard isNew else { return }
                draft = .new(kind: kind, dewormingKind: draft.dewormingKind, date: draft.date, summary: summary())
            }
            .onChange(of: draft.dewormingKind) { _, kind in
                guard isNew, draft.kind == .deworming else { return }
                draft.useDewormingKind(kind, summary: summary())
            }
        }
    }

    private func summary() -> PetHealthSummary {
        PetHealthSummary(pet: request.pet)
    }

    private func pickSuggestion(_ name: String) {
        if draft.kind == .vaccine, isNew {
            draft.useVaccine(named: name, summary: summary())
        } else {
            draft.name = name
        }
    }

    private func cancel() {
        dismiss()
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func save() {
        let log = HealthLog(context: context)
        do {
            switch (draft.kind, request.target) {
            case (.vaccine, .vaccine(let existing)):
                try log.saveVaccine(draft, for: request.pet, editing: existing)
            case (.vaccine, _):
                try log.saveVaccine(draft, for: request.pet)
            case (.deworming, .deworming(let existing)):
                try log.saveDeworming(draft, for: request.pet, editing: existing)
            case (.deworming, _):
                try log.saveDeworming(draft, for: request.pet)
            case (.weight, .weight(let existing)):
                try log.saveWeight(draft, for: request.pet, editing: existing)
            case (.weight, _):
                try log.saveWeight(draft, for: request.pet)
            }
            onSaved()
            dismiss()
        } catch {
            context.rollback()
            isShowingSaveError = true
        }
    }

    private func delete() {
        let log = HealthLog(context: context)
        do {
            switch request.target {
            case .vaccine(let record):   try log.delete(record)
            case .deworming(let record): try log.delete(record)
            case .weight(let record):    try log.delete(record)
            case .new:                   break
            }
            onSaved()
            dismiss()
        } catch {
            context.rollback()
            isShowingSaveError = true
        }
    }
}

#Preview {
    let container = PreviewData.container()
    let pet = PreviewData.firstPet(in: container)
    return RecordSheet(request: RecordRequest(pet: pet, kind: .deworming), onSaved: {})
        .modelContainer(container)
        .environment(\.locale, BonesFormat.locale)
}

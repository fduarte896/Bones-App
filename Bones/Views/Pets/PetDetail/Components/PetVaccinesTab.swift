//
//  PetVaccinesTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetVaccinesTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    // Confirmación de borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    @State private var pendingDelete: Vaccine?
    
    // Año de referencia: el de la próxima vacuna pendiente (más cercana en el futuro)
    private var referenceYear: Int? {
        let now = Date()
        if let next = viewModel.vaccines.first(where: { $0.date >= now && !$0.isCompleted }) {
            return Calendar.current.component(.year, from: next.date)
        }
        return nil
    }
    
    var body: some View {
        List {
            if viewModel.vaccines.isEmpty {
                ContentUnavailableView("Sin vacunas registradas",
                                       systemImage: "syringe")
            } else {
                ForEach(viewModel.vaccines, id: \.id) { vac in
                    NavigationLink {
                        EventDetailView(event: vac)
                    } label: {
                        VaccineRow(
                            vac: vac,
                            referenceYear: referenceYear,
                            allVaccines: viewModel.vaccines
                        )
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            vac.isCompleted.toggle()
                            NotificationManager.shared.cancelNotification(id: vac.id)
                            try? context.save()
                            viewModel.fetchEvents()
                        } label: {
                            Label("Completar", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            startDelete(for: vac)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }   // refresca si usas @Published
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            viewModel.fetchEvents()
        }
        .confirmationDialog(
            "¿Eliminar también futuras dosis?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            if pendingFutureCount > 0 {
                Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                    deleteThisAndFuture()
                }
                Button("Eliminar solo esta", role: .destructive) {
                    if let vac = pendingDelete { deleteSingle(vac) }
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    if let vac = pendingDelete { deleteSingle(vac) }
                }
            }
            Button("Cancelar", role: .cancel) { clearPending() }
        } message: {
            if pendingFutureCount > 0 {
                Text("Se encontraron \(pendingFutureCount) dosis futuras relacionadas. ¿Deseas borrarlas también?")
            } else {
                Text("Esta acción no se puede deshacer.")
            }
        }
    }
}

// MARK: - Fila
private struct VaccineRow: View {
    @Bindable var vac: Vaccine
    var referenceYear: Int?
    var allVaccines: [Vaccine]
    
    var body: some View {
        let parsed = DoseSeries.splitDose(from: vac.vaccineName)
        let numbers = DoseSeries.parseDoseNumbers(from: vac.vaccineName)
        let isBooster = DoseSeries.isBooster(vac, among: allVaccines)
        
        // Regla de presentación:
        // - Booster: "Dosis de refuerzo"
        // - Primera (0 o 1): "Primera dosis"
        // - Si hay números: "Dosis X/Y"
        // - Si no hay números: no muestra subtítulo de dosis
        let doseLabel: String? = {
            if isBooster { return "Dosis de refuerzo" }
            if let cur = numbers.current {
                if cur <= 1 { return "Primera dosis" }
                if let tot = numbers.total { return "Dosis \(cur)/\(tot)" }
                return "Dosis \(cur)"
            }
            return nil
        }()
        
        let vacYear = Calendar.current.component(.year, from: vac.date)
        let showYear: Bool = {
            guard let ref = referenceYear else { return false }
            return vacYear > ref    // ahora solo resalta años FUTUROS distintos
        }()
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.base).fontWeight(.semibold)
                
                if let doseLabel {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let m = vac.manufacturer, !m.isEmpty {
                    Text("Fabricante: \(m)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text(vac.date, format: .dateTime.day().month().hour().minute())
                    if showYear {
                        Text("· \(vacYear)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: vac.isCompleted ? "checkmark.circle.fill"
                                              : "syringe")
                .foregroundStyle(vac.isCompleted ? .green : .accentColor)
        }
    }
}

// MARK: - Helpers de borrado en serie
private extension PetVaccinesTab {
    func startDelete(for vac: Vaccine) {
        let count = max(0, DoseSeries.futureVaccines(from: vac, in: context).count - 1)
        if count == 0 {
            deleteSingle(vac)
        } else {
            pendingDelete = vac
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    func deleteSingle(_ vac: Vaccine) {
        NotificationManager.shared.cancelNotification(id: vac.id)
        context.delete(vac)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    
    func deleteThisAndFuture() {
        guard let vac = pendingDelete else { return }
        let all = DoseSeries.futureVaccines(from: vac, in: context)
        for v in all {
            NotificationManager.shared.cancelNotification(id: v.id)
            context.delete(v)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    
    func clearPending() {
        pendingFutureCount = 0
        pendingDelete = nil
        showingDeleteDialog = false
    }
}

// MARK: - Previews

#Preview("Vacunas – Diverso") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.seedDiverseVaccines(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Vacunas – Vacío") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.emptyPet(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

// Host que crea el VM y le inyecta el context del entorno
private struct PetVaccinesTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        PetVaccinesTab(viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

// Datos de ejemplo para previews
private enum VaccinesPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            Grooming.self,
            WeightEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
    
    // Pet sin vacunas
    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }
    
    // Pet con variedad de vacunas
    @discardableResult
    static func seedDiverseVaccines(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        
        let now = Date()
        // Futuras con esquema de dosis
        let v1 = Vaccine(date: now.addingTimeInterval(2 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Rabia (dosis 1/3)",
                         manufacturer: "VetLabs",
                         notes: "Primera dosis")
        let v2 = Vaccine(date: now.addingTimeInterval(30 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Rabia (dosis 2/3)",
                         manufacturer: "VetLabs",
                         notes: "Refuerzo 1")
        // Pasada del mismo esquema, marcada completada
        let v0 = Vaccine(date: now.addingTimeInterval(-10 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Rabia (dosis 0/3)",
                         manufacturer: "VetLabs",
                         notes: "Dosis previa")
        v0.isCompleted = true
        
        // Otra vacuna sin esquema de dosis y sin fabricante
        let v3 = Vaccine(date: now.addingTimeInterval(7 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Moquillo",
                         manufacturer: nil,
                         notes: "Aplicar por la mañana")
        
        // Otra con fabricante vacío y en el pasado, no completada
        let v4 = Vaccine(date: now.addingTimeInterval(-3 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Parvovirus",
                         manufacturer: "",
                         notes: "Control")
        
        ctx.insert(v0)
        ctx.insert(v1)
        ctx.insert(v2)
        ctx.insert(v3)
        ctx.insert(v4)
        try? ctx.save()
        return pet
    }
}


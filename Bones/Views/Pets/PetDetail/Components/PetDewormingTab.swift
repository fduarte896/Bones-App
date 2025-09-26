//
//  PetDewormingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetDewormingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    // Confirmación de borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    @State private var pendingDelete: Deworming?
    
    var body: some View {
        List {
            if viewModel.dewormings.isEmpty {
                ContentUnavailableView("Sin desparasitaciones registradas",
                                       systemImage: "bandage.fill")
            } else {
                ForEach(viewModel.dewormings, id: \.id) { dew in
                    NavigationLink {
                        EventDetailView(event: dew)
                    } label: {
                        DewormingRow(dew: dew)
                    }
                    // Swipe: completar
                    .swipeActions(edge: .leading) {
                        Button {
                            dew.isCompleted.toggle()
                            NotificationManager.shared.cancelNotification(id: dew.id)
                            try? context.save()
                            viewModel.fetchEvents()
                        } label: { Label("Completar", systemImage: "checkmark") }
                        .tint(.green)
                    }
                    // Swipe: borrar (con confirmación de serie)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            startDelete(for: dew)
                        } label: { Label("Borrar", systemImage: "trash") }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
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
                    if let dew = pendingDelete { deleteSingle(dew) }
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    if let dew = pendingDelete { deleteSingle(dew) }
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
private struct DewormingRow: View {
    @Bindable var dew: Deworming
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación")
                    .fontWeight(.semibold)
                Text(dew.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: dew.isCompleted ? "checkmark.circle.fill"
                                              : "bandage.fill")
                .foregroundStyle(dew.isCompleted ? .green : .accentColor)
        }
    }
}

// MARK: - Helpers de borrado en serie
private extension PetDewormingTab {
    func startDelete(for dew: Deworming) {
        let count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
        if count == 0 {
            deleteSingle(dew)
        } else {
            pendingDelete = dew
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    func deleteSingle(_ dew: Deworming) {
        NotificationManager.shared.cancelNotification(id: dew.id)
        context.delete(dew)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    
    func deleteThisAndFuture() {
        guard let dew = pendingDelete else { return }
        let all = DoseSeries.futureDewormings(from: dew, in: context)
        for d in all {
            NotificationManager.shared.cancelNotification(id: d.id)
            context.delete(d)
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

#Preview("Desparasitación – Diverso") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.seedDiverseDewormings(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Desparasitación – Vacío") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.emptyPet(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

// Host que crea el VM y le inyecta el context del entorno
private struct PetDewormingTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        PetDewormingTab(viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

// Datos de ejemplo para previews
private enum DewPreviewData {
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
    
    // Pet sin desparasitaciones
    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }
    
    // Pet con variedad de desparasitaciones
    @discardableResult
    static func seedDiverseDewormings(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        
        let now = Date()
        // Dos series distintas con seriesID estable
        let seriesA = UUID()
        let seriesB = UUID()
        
        // Serie 1: "Tableta mensual" (pasada completada + futuras)
        let d0 = Deworming(date: now.addingTimeInterval(-10 * 24 * 3600),
                           pet: pet,
                           notes: "Tableta mensual",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        d0.isCompleted = true
        
        let d1 = Deworming(date: now.addingTimeInterval(7 * 24 * 3600),
                           pet: pet,
                           notes: "Tableta mensual",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        let d2 = Deworming(date: now.addingTimeInterval(37 * 24 * 3600),
                           pet: pet,
                           notes: "Tableta mensual",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        
        // Serie 2: "Pipeta externa" (una próxima y una pasada)
        let d3 = Deworming(date: now.addingTimeInterval(1 * 24 * 3600),
                           pet: pet,
                           notes: "Pipeta externa",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        let d4 = Deworming(date: now.addingTimeInterval(-3 * 24 * 3600),
                           pet: pet,
                           notes: "Pipeta externa",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        
        ctx.insert(d0)
        ctx.insert(d1)
        ctx.insert(d2)
        ctx.insert(d3)
        ctx.insert(d4)
        try? ctx.save()
        return pet
    }
}

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
    
    var body: some View {
        List {
            if viewModel.dewormings.isEmpty {
                ContentUnavailableView("Sin desparasitaciones registradas",
                                       systemImage: "bandage.fill")
            } else {
                ForEach(viewModel.dewormings, id: \.id) { dew in
                    DewormingRow(dew: dew, context: context)
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
    }
}

// MARK: - Fila
private struct DewormingRow: View {
    @Bindable var dew: Deworming
    var context: ModelContext
    
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
        // Swipe: completar
        .swipeActions(edge: .leading) {
            Button {
                dew.isCompleted.toggle()
                try? context.save()
            } label: { Label("Completar", systemImage: "checkmark") }
            .tint(.green)
        }
        // Swipe: borrar
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: dew.id)
                context.delete(dew)
                try? context.save()
            } label: { Label("Borrar", systemImage: "trash") }
        }
    }
}


// MARK: - Previews

#Preview("PetDewormingTab – Con datos") {
    // 1) Contenedor en memoria con el esquema necesario
    let container = PreviewData.makeContainer()
    // 2) Insertamos una mascota y varias desparasitaciones
    let pet = PreviewData.seedDewormings(in: container)
    // 3) ViewModel real configurado con el mismo context
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ModelContext(container))
    vm.fetchEvents()
    // 4) Vista con el mismo container en el entorno
    return PetDewormingTab(viewModel: vm)
        .modelContainer(container)
}

#Preview("PetDewormingTab – Vacío") {
    let container = PreviewData.makeContainer()
    // Solo la mascota, sin eventos
    let ctx = ModelContext(container)
    let pet = Pet(name: "Mishi", species: .gato, sex: .female)
    ctx.insert(pet)
    try? ctx.save()
    
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ctx)
    vm.fetchEvents()
    
    return PetDewormingTab(viewModel: vm)
        .modelContainer(container)
}

// Datos de ejemplo para este preview
private enum PreviewData {
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
    
    @discardableResult
    static func seedDewormings(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        
        let loki = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(loki)
        
        let now = Date()
        let cal = Calendar.current
        
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: now)!
        let nextMonth = cal.date(byAdding: .month, value: 1, to: now)!
        
        let dew1 = Deworming(date: lastMonth, pet: loki, notes: "Tableta mensual")
        dew1.isCompleted = true
        dew1.completedAt = lastMonth
        
        let dew2 = Deworming(date: twoWeeksAgo, pet: loki, notes: "Pipeta")
        dew2.isCompleted = true
        dew2.completedAt = now
        
        let dew3 = Deworming(date: nextMonth, pet: loki, notes: "Recordatorio próximo")
        
        ctx.insert(dew1)
        ctx.insert(dew2)
        ctx.insert(dew3)
        
        try? ctx.save()
        return loki
    }
}

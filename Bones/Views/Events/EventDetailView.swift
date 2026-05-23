//  EventDetailView.swift
//  Bones

import SwiftUI
import SwiftData

struct EventDetailView: View {
    let event: any BasicEvent

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false

    var body: some View {
        Group {
            switch event {
            case let vac as Vaccine:
                VaccineDetailView(vac: vac) { startDelete(for: vac) }
            case let dew as Deworming:
                DewormingDetailView(dew: dew) { startDelete(for: dew) }
            case let weight as WeightEntry:
                WeightEntryDetailView(weight: weight) { deleteSingle(event: weight) }
            default:
                Text("Tipo de evento no soportado.")
            }
        }
        .navigationTitle(event.displayType.isEmpty ? "Detalle" : event.displayType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(event.isCompleted ? "Desmarcar" : "Completar") { toggleCompleted() }
            }
        }
        .confirmationDialog("¿Eliminar también futuras dosis?", isPresented: $showingDeleteDialog, titleVisibility: .visible) {
            if pendingFutureCount > 0 {
                Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) { deleteThisAndFuture() }
                Button("Eliminar solo esta", role: .destructive) { deleteSingle(event: event) }
            } else {
                Button("Eliminar", role: .destructive) { deleteSingle(event: event) }
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

// MARK: - Toolbar

private extension EventDetailView {
    func toggleCompleted() {
        event.isCompleted.toggle()
        event.completedAt = event.isCompleted ? Date() : nil
        NotificationManager.shared.cancelNotification(id: event.id)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - Delete helpers

private extension EventDetailView {
    func deleteSingle(event: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: event.id)
        context.delete(event)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        dismiss()
    }

    func startDelete(for vac: Vaccine) {
        let count = max(0, DoseSeries.futureVaccines(from: vac, in: context).count - 1)
        count == 0 ? deleteSingle(event: vac) : setPending(count)
    }

    func startDelete(for dew: Deworming) {
        let count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
        count == 0 ? deleteSingle(event: dew) : setPending(count)
    }

    func setPending(_ count: Int) {
        pendingFutureCount = count
        showingDeleteDialog = true
    }

    func deleteThisAndFuture() {
        switch event {
        case let vac as Vaccine:
            DoseSeries.futureVaccines(from: vac, in: context).forEach {
                NotificationManager.shared.cancelNotification(id: $0.id); context.delete($0)
            }
        case let dew as Deworming:
            DoseSeries.futureDewormings(from: dew, in: context).forEach {
                NotificationManager.shared.cancelNotification(id: $0.id); context.delete($0)
            }
        default: break
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        clearPending()
        dismiss()
    }

    func clearPending() {
        pendingFutureCount = 0
        showingDeleteDialog = false
    }
}

// MARK: - Previews

private enum EventDetailPreviewData {
    static func makeContainer() -> ModelContainer {
        try! ModelContainer(
            for: Schema([Pet.self, Vaccine.self, Deworming.self, WeightEntry.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

#Preview("Detalle – Vacuna") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    let vac = Vaccine(date: Date().addingTimeInterval(86400), pet: pet, vaccineName: "Rabia (dosis 1/3)", manufacturer: "VetLabs", notes: "Primera dosis")
    ctx.insert(vac); try? ctx.save()
    return NavigationStack { EventDetailView(event: vac) }.modelContainer(container)
}

#Preview("Detalle – Desparasitación") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    let dew = Deworming(date: Date().addingTimeInterval(7 * 86400), pet: pet, notes: "Tableta mensual")
    ctx.insert(dew); try? ctx.save()
    return NavigationStack { EventDetailView(event: dew) }.modelContainer(container)
}

#Preview("Detalle – Peso") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    let weight = WeightEntry(date: Date().addingTimeInterval(-2 * 86400), pet: pet, weightKg: 23.4, notes: "Post entrenamiento")
    ctx.insert(weight); try? ctx.save()
    return NavigationStack { EventDetailView(event: weight) }.modelContainer(container)
}

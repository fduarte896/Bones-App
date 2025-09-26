//
//  PetUpcomingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//

import SwiftUI
import SwiftData

struct PetUpcomingEventsTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context

    // Confirmación de borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    @State private var pendingMed: Medication?
    @State private var pendingVac: Vaccine?
    @State private var pendingDew: Deworming?

    var body: some View {
        List {
            if viewModel.groupedUpcomingEvents.isEmpty {
                ContentUnavailableView("Sin próximos eventos",
                                       systemImage: "checkmark.circle")
            } else {
                ForEach(viewModel.groupedUpcomingEvents) { section in
                    Section(section.title){
                        ForEach(section.items, id: \.id) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                            } label: {
                                EventRow(event: event)
                            }
                            // Swipe: borrar con confirmación de serie
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    startDelete(for: event)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                            // Swipe: completar
                            .swipeActions(edge: .leading) {
                                Button {
                                    event.isCompleted = true
                                    NotificationManager.shared.cancelNotification(id: event.id)
                                    try? context.save()
                                    viewModel.fetchEvents()
                                } label: {
                                    Label("Completado", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
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
                if let _ = pendingMed {
                    Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                        deleteThisAndFutureMed()
                    }
                    Button("Eliminar solo esta", role: .destructive) {
                        if let med = pendingMed { deleteSingle(med) }
                    }
                } else if let _ = pendingVac {
                    Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                        deleteThisAndFutureVac()
                    }
                    Button("Eliminar solo esta", role: .destructive) {
                        if let vac = pendingVac { deleteSingle(vac) }
                    }
                } else if let _ = pendingDew {
                    Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                        deleteThisAndFutureDew()
                    }
                    Button("Eliminar solo esta", role: .destructive) {
                        if let dew = pendingDew { deleteSingle(dew) }
                    }
                }
            } else {
                // En esta pantalla no presentamos diálogo cuando no hay futuras;
                // startDelete() elimina directamente en ese caso.
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

// MARK: - Row
private struct EventRow: View {
    let event: any BasicEvent
    
    // Separa " (dosis X/Y)" en cualquier displayName
    private func splitDose(from name: String) -> (base: String, dose: String?) {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1) // "("
        let closingParenIndex = name.index(before: name.endIndex)            // ")"
        guard closingParenIndex > openParenIndex else { return (name, nil) }
        let contentStart = name.index(after: openParenIndex)
        let contentEnd   = closingParenIndex
        let inside = String(name[contentStart..<contentEnd]) // "dosis X/Y"
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
    
    var body: some View {
        let parsed = splitDose(from: event.displayName)
    
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Título sin sufijo de dosis
                Text(parsed.base).fontWeight(.semibold)
                
                // Línea dedicada al número de la dosis (si aplica)
                if let doseLabel = parsed.dose {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !event.displayType.isEmpty {
                    Text(event.displayType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(event.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "bell")
        }
    }
}

// MARK: - Borrado en serie
private extension PetUpcomingEventsTab {
    func startDelete(for event: any BasicEvent) {
        switch event {
        case let med as Medication:
            let count = max(0, DoseSeries.futureMedications(from: med, in: context).count - 1)
            if count == 0 {
                deleteSingle(med)
            } else {
                pendingMed = med
                pendingFutureCount = count
                showingDeleteDialog = true
            }
        case let vac as Vaccine:
            let count = max(0, DoseSeries.futureVaccines(from: vac, in: context).count - 1)
            if count == 0 {
                deleteSingle(vac)
            } else {
                pendingVac = vac
                pendingFutureCount = count
                showingDeleteDialog = true
            }
        case let dew as Deworming:
            let count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
            if count == 0 {
                deleteSingle(dew)
            } else {
                pendingDew = dew
                pendingFutureCount = count
                showingDeleteDialog = true
            }
        default:
            // Grooming y WeightEntry se eliminan directamente
            deleteSingle(event)
        }
    }
    
    func deleteSingle(_ event: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: event.id)
        context.delete(event)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    
    func deleteThisAndFutureMed() {
        guard let med = pendingMed else { return }
        for m in DoseSeries.futureMedications(from: med, in: context) {
            NotificationManager.shared.cancelNotification(id: m.id)
            context.delete(m)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    func deleteThisAndFutureVac() {
        guard let vac = pendingVac else { return }
        for v in DoseSeries.futureVaccines(from: vac, in: context) {
            NotificationManager.shared.cancelNotification(id: v.id)
            context.delete(v)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    func deleteThisAndFutureDew() {
        guard let dew = pendingDew else { return }
        for d in DoseSeries.futureDewormings(from: dew, in: context) {
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
        pendingMed = nil
        pendingVac = nil
        pendingDew = nil
        showingDeleteDialog = false
    }
}

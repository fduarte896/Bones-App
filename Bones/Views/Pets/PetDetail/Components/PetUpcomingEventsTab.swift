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
                                       systemImage: "checkmark.circle",
                                       description: Text("Cuando programes eventos aparecerán aquí."))
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
    
    private var icon: String {
        switch event {
        case is Medication:  "pills.fill"
        case is Vaccine:     "syringe"
        case is Deworming:   "ladybug.fill"
        case is Grooming:    "scissors"
        case is WeightEntry: "scalemass"
        default:             "bell"
        }
    }
    
    private var tint: Color {
        switch event {
        case is Medication:  return .blue
        case is Vaccine:     return .green
        case is Deworming:   return .orange
        case is Grooming:    return .teal
        case is WeightEntry: return .gray
        default:             return .secondary
        }
    }
    
    var body: some View {
        let parsed = splitDose(from: event.displayName)
    
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(.systemGray6)))
            
            VStack(alignment: .leading, spacing: 2) {
                // Título sin sufijo de dosis
                Text(parsed.base).fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    if !event.displayType.isEmpty {
                        TagChip(text: shortTypeLabel, tint: tint)
                    }
                    if let doseLabel = parsed.dose {
                        TagChip(text: doseLabel, tint: .secondary)
                    }
                    if !isTodayOrTomorrow {
                        TagChip(text: event.date.formatted(.dateTime.day().month().hour().minute()), tint: .secondary)
                    }
                    if isOverdue {
                        TagChip(text: "Vencida", tint: .red)
                    }
                }
            }

            Spacer()
            
            if isTodayOrTomorrow {
                Text(event.date, format: .dateTime.hour().minute())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
        }
    }
    
    private var isOverdue: Bool {
        !event.isCompleted && event.date < Date()
    }
    
    private var isTodayOrTomorrow: Bool {
        let cal = Calendar.current
        return cal.isDateInToday(event.date) || cal.isDateInTomorrow(event.date)
    }
    
    private var shortTypeLabel: String {
        if event.displayType == "Desparasitación" { return "Despar." }
        return event.displayType
    }
    
}

private struct TagChip: View {
    let text: String
    let tint: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint)
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
// MARK: - Preview

#Preview("Próximos – Variado") {
    let container = PreviewData.makeContainer()
    PreviewData.seed(in: container)
    return PetUpcomingEventsPreviewHost()
        .modelContainer(container)
}

private struct PetUpcomingEventsPreviewHost: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init() {
        let sampleID = PreviewData.samplePetID
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: sampleID))
    }
    
    var body: some View {
        PetUpcomingEventsTab(viewModel: vm)
            .onAppear { vm.inject(context: context) }
    }
}

private enum PreviewData {
    static let samplePetID = UUID()
    
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            Grooming.self,
            WeightEntry.self
        ] as [any PersistentModel.Type])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
    
    static func seed(in container: ModelContainer) {
        let ctx = ModelContext(container)
        let cal = Calendar.current
        let now = Date()
        
        // Mascota
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        pet.id = samplePetID
        ctx.insert(pet)
        
        // Medicamentos (hoy, mañana, semana próxima)
        ctx.insert(Medication(date: now.addingTimeInterval(2 * 3600),
                              pet: pet,
                              name: "Amoxicilina (dosis 1/3)",
                              dosage: "250 mg",
                              frequency: "cada 8 h"))
        ctx.insert(Medication(date: cal.date(byAdding: .day, value: 1, to: now)!,
                              pet: pet,
                              name: "Amoxicilina (dosis 2/3)",
                              dosage: "250 mg",
                              frequency: "cada 8 h"))
        ctx.insert(Medication(date: cal.date(byAdding: .day, value: 5, to: now)!,
                              pet: pet,
                              name: "Omeprazol",
                              dosage: "10 mg",
                              frequency: "cada día"))
        
        // Vacunas (futuras)
        ctx.insert(Vaccine(date: cal.date(byAdding: .day, value: 3, to: now)!,
                           pet: pet,
                           vaccineName: "Rabia (dosis 2/3)",
                           manufacturer: "VetLabs"))
        ctx.insert(Vaccine(date: cal.date(byAdding: .day, value: 20, to: now)!,
                           pet: pet,
                           vaccineName: "Moquillo",
                           manufacturer: "VetLabs"))
        
        // Desparasitación (futura cercana)
        ctx.insert(Deworming(date: cal.date(byAdding: .day, value: 7, to: now)!,
                             pet: pet,
                             notes: "Drontal Plus (dosis 1/2)",
                             prescriptionImageData: nil,
                             seriesID: UUID()))
        
        // Grooming (esta semana)
        let groom = Grooming(date: cal.date(byAdding: .day, value: 4, to: now)!,
                             pet: pet,
                             location: "PetSpa",
                             notes: "Corte y baño",
                             services: [.bano, .cortePelo],
                             totalPrice: 45)
        ctx.insert(groom)
        
        // Peso (mañana)
        ctx.insert(WeightEntry(date: cal.date(byAdding: .day, value: 1, to: now)!,
                               pet: pet,
                               weightKg: 18.4,
                               notes: "Control mensual"))
        
        try? ctx.save()
    }
}

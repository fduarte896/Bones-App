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
    
    // Estado de expansión por serie (clave: baseName)
    @State private var expandedSeries: Set<String> = []
    
    // Estado de expansión por subsección dentro de cada serie (añadimos "overdue")
    private struct SubsectionsState {
        var next: Bool = true
        var overdue: Bool = true
        var future: Bool = true
        var history: Bool = false
    }
    @State private var expandedSubsections: [String: SubsectionsState] = [:]
    
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
                ForEach(orderedSummaries) { summary in
                    Section {
                        if expandedSeries.contains(summary.baseName) {
                            let now = Date()
                            let binding = bindingForSubsections(summary.baseName)
                            
                            // Próxima (si existe) — disclosure propio
                            if let next = summary.nextPending {
                                DisclosureGroup(isExpanded: binding.next) {
                                    NavigationLink {
                                        EventDetailView(event: next)
                                    } label: {
                                        VaccineRow(
                                            vac: next,
                                            referenceYear: referenceYear,
                                            allVaccines: summary.items
                                        )
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            next.isCompleted.toggle()
                                            NotificationManager.shared.cancelNotification(id: next.id)
                                            try? context.save()
                                            viewModel.fetchEvents()
                                        } label: {
                                            Label("Completar", systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            startDelete(for: next)
                                        } label: {
                                            Label("Borrar", systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    Text("Próxima")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Vencidas (pendientes < hoy), excluyendo la “Próxima” si ya es vencida
                            let overduePending = summary.items.filter { vac in
                                guard !vac.isCompleted, vac.date < now else { return false }
                                if let next = summary.nextPending {
                                    return vac.id != next.id
                                }
                                return true
                            }
                            if !overduePending.isEmpty {
                                DisclosureGroup(isExpanded: binding.overdue) {
                                    ForEach(overduePending.sorted(by: { $0.date < $1.date }), id: \.id) { vac in
                                        NavigationLink {
                                            EventDetailView(event: vac)
                                        } label: {
                                            VaccineRow(
                                                vac: vac,
                                                referenceYear: referenceYear,
                                                allVaccines: summary.items
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
                                } label: {
                                    Text("Vencidas")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Dosis futuras (pendientes > hoy), excluyendo la "Próxima"
                            let futurePending = summary.items.filter { vac in
                                guard !vac.isCompleted, vac.date > now else { return false }
                                if let next = summary.nextPending {
                                    return vac.id != next.id
                                }
                                return true
                            }
                            if !futurePending.isEmpty {
                                DisclosureGroup(isExpanded: binding.future) {
                                    ForEach(futurePending.sorted(by: { $0.date < $1.date }), id: \.id) { vac in
                                        NavigationLink {
                                            EventDetailView(event: vac)
                                        } label: {
                                            VaccineRow(
                                                vac: vac,
                                                referenceYear: referenceYear,
                                                allVaccines: summary.items
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
                                } label: {
                                    Text("Dosis futuras")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Historial (solo completadas) — cerrado por defecto
                            let history = summary.items.filter { $0.isCompleted }
                            if !history.isEmpty {
                                DisclosureGroup(isExpanded: binding.history) {
                                    ForEach(history.sorted(by: { $0.date > $1.date }), id: \.id) { vac in
                                        NavigationLink {
                                            EventDetailView(event: vac)
                                        } label: {
                                            VaccineRow(
                                                vac: vac,
                                                referenceYear: referenceYear,
                                                allVaccines: summary.items
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
                                } label: {
                                    Text("Historial")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        // Header “tappable” que actúa como el label del DisclosureGroup de la serie
                        Button {
                            if expandedSeries.contains(summary.baseName) {
                                expandedSeries.remove(summary.baseName)
                            } else {
                                expandedSeries.insert(summary.baseName)
                                // Inicializa estado de subsecciones si no existe
                                ensureSubsectionsState(for: summary)
                            }
                        } label: {
                            SeriesRow(summary: summary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchEvents()
            autoExpandCriticalSeries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            viewModel.fetchEvents()
            autoExpandCriticalSeries()
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
    
    // Orden: atrasadas primero, luego por próxima más cercana, luego alfabético
    private var orderedSummaries: [PetDetailViewModel.VaccineSeriesSummary] {
        let now = Date()
        func priority(_ s: PetDetailViewModel.VaccineSeriesSummary) -> (Int, Date?, String) {
            let isOverdue = (s.nextPending?.date ?? now) < now && s.nextPending != nil
            let p0 = isOverdue ? 0 : 1
            let p1 = s.nextPending?.date
            return (p0, p1, s.baseName.lowercased())
        }
        return viewModel.vaccineSeriesSummaries.sorted { a, b in
            let pa = priority(a), pb = priority(b)
            if pa.0 != pb.0 { return pa.0 < pb.0 }
            if pa.1 != pb.1 { return (pa.1 ?? .distantFuture) < (pb.1 ?? .distantFuture) }
            return pa.2 < pb.2
        }
    }
    
    private func autoExpandCriticalSeries() {
        let now = Date()
        let soon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        var toExpand: Set<String> = expandedSeries
        for s in viewModel.vaccineSeriesSummaries {
            var shouldExpand = false
            if let next = s.nextPending?.date {
                if next < now || next <= soon {
                    shouldExpand = true
                }
            }
            // Si hay vencidas, también expandir
            let hasOverdue = s.items.contains { !$0.isCompleted && $0.date < now }
            if shouldExpand || hasOverdue {
                toExpand.insert(s.baseName)
                // Asegura estado por defecto de subsecciones:
                // Próxima, Vencidas y Futuras abiertas; Historial cerrado
                if expandedSubsections[s.baseName] == nil {
                    expandedSubsections[s.baseName] = SubsectionsState(next: true, overdue: true, future: true, history: false)
                } else {
                    // Si ya existe, al menos abre overdue cuando hay vencidas
                    if hasOverdue {
                        expandedSubsections[s.baseName]?.overdue = true
                    }
                }
            }
        }
        expandedSeries = toExpand
    }
    
    // MARK: - Subsections state helpers (clon de desparasitación, con overdue)
    private func ensureSubsectionsState(for summary: PetDetailViewModel.VaccineSeriesSummary) {
        if expandedSubsections[summary.baseName] == nil {
            expandedSubsections[summary.baseName] = SubsectionsState(next: true, overdue: true, future: true, history: false)
        }
    }
    
    private func bindingForSubsections(_ baseName: String) -> (next: Binding<Bool>, overdue: Binding<Bool>, future: Binding<Bool>, history: Binding<Bool>) {
        if expandedSubsections[baseName] == nil {
            expandedSubsections[baseName] = SubsectionsState()
        }
        return (
            Binding(
                get: { expandedSubsections[baseName, default: SubsectionsState()].next },
                set: { expandedSubsections[baseName, default: SubsectionsState()].next = $0 }
            ),
            Binding(
                get: { expandedSubsections[baseName, default: SubsectionsState()].overdue },
                set: { expandedSubsections[baseName, default: SubsectionsState()].overdue = $0 }
            ),
            Binding(
                get: { expandedSubsections[baseName, default: SubsectionsState()].future },
                set: { expandedSubsections[baseName, default: SubsectionsState()].future = $0 }
            ),
            Binding(
                get: { expandedSubsections[baseName, default: SubsectionsState()].history },
                set: { expandedSubsections[baseName, default: SubsectionsState()].history = $0 }
            )
        )
    }
}

// MARK: - Fila de dosis
private struct VaccineRow: View {
    @Bindable var vac: Vaccine
    var referenceYear: Int?
    var allVaccines: [Vaccine]
    
    var body: some View {
        let parsed = DoseSeries.splitDose(from: vac.vaccineName)
        let numbers = DoseSeries.parseDoseNumbers(from: vac.vaccineName)
        let isBooster = DoseSeries.isBooster(vac, among: allVaccines)
        let isOverdue = !vac.isCompleted && vac.date < Date()
        
        // Regla de presentación:
        // - Booster: "Dosis de refuerzo"
        // - Primera (0 o 1): "Primera dosis"
        // - Si hay números: "Dosis X/Y"
        // - Si no hay números: no muestra subtítulo de dosis
        // Añadimos "(Vencida)" cuando corresponda y coloreamos en rojo.
        let baseDoseLabel: String? = {
            if isBooster { return "Dosis de refuerzo" }
            if let cur = numbers.current {
                if cur <= 1 { return "Primera dosis" }
                if let tot = numbers.total { return "Dosis \(cur)/\(tot)" }
                return "Dosis \(cur)"
            }
            return nil
        }()
        let doseLabelToShow: String? = {
            if let label = baseDoseLabel {
                return isOverdue ? "\(label) (Vencida)" : "\(label)"
            } else {
                return isOverdue ? "Vencida" : nil
            }
        }()
        
        let vacYear = Calendar.current.component(.year, from: vac.date)
        let showYear: Bool = {
            guard let ref = referenceYear else { return false }
            return vacYear > ref
        }()
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.base).fontWeight(.semibold)
                
                if let doseLabelToShow {
                    Text(doseLabelToShow)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)
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

// MARK: - Fila de serie (encabezado)
private struct SeriesRow: View {
    let summary: PetDetailViewModel.VaccineSeriesSummary
    
    // Nuevo: detectar si hay dosis vencidas pendientes en la serie
    private var hasOverdue: Bool {
        let now = Date()
        return summary.items.contains { !$0.isCompleted && $0.date < now }
    }
    
    private var statusText: String {
        // Prioriza mostrar "Vencida" si hay pendientes en el pasado
        if hasOverdue {
            return "Vencida"
        }
        switch summary.status {
        case .notStarted:
            return "No iniciada"
        case .completed:
            return "Completada"
        case .inProgress(let current, let total):
            if let total {
                return "En progreso (\(current)/\(total))"
            } else {
                return "En progreso"
            }
        case .booster(let next):
            if let d = next {
                return "Refuerzo • \(d.formatted(date: .abbreviated, time: .omitted))"
            } else {
                return "Refuerzo"
            }
        }
    }
    
    private var nextText: String {
        if let next = summary.nextPending {
            if let overdue = summary.overdueDays, overdue > 0, next.date < Date() {
                return "Atrasada \(overdue) d"
            } else {
                return next.date.formatted(date: .abbreviated, time: .omitted)
            }
        } else {
            return "Sin próxima"
        }
    }
    
    private var lastText: String {
        if let last = summary.lastCompleted {
            return last.date.formatted(date: .abbreviated, time: .omitted)
        } else {
            return "—"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.baseName)
                    .fontWeight(.semibold)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(hasOverdue ? .red : .secondary)
                HStack(spacing: 12) {
                    LabeledValue(label: "Última", value: lastText)
                    LabeledValue(label: "Próxima", value: nextText)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "syringe")
        }
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
            Text(value)
                .fontWeight(.medium)
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
        
        // Otra con fabricante vacío y en el pasado, no completada (vencida)
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

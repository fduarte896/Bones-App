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
    
    // Confirmación de borrado de serie completa
    @State private var pendingSeriesItems: [Vaccine] = []
    @State private var pendingSeriesCount: Int = 0
    @State private var showingSeriesDeleteDialog = false
    
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
                        HStack(spacing: 12) {
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
                            
                            Spacer(minLength: 0)
                            
                            Button {
                                startDeleteSeries(summary)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Eliminar serie")
                        }
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
        .confirmationDialog(
            "¿Eliminar toda la serie?",
            isPresented: $showingSeriesDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Eliminar \(pendingSeriesCount) dosis", role: .destructive) {
                deleteSeries()
            }
            Button("Cancelar", role: .cancel) { clearSeriesPending() }
        } message: {
            Text("Se eliminarán todas las dosis de esta serie. Esta acción no se puede deshacer.")
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
    
    
    private var boosterChipLabel: String? {
        let boosters = summary.items.filter { DoseSeries.isBooster($0, among: summary.items) }
        guard !boosters.isEmpty else { return nil }
        let completedBoosters = boosters.filter { $0.isCompleted }.count
        let current = min(completedBoosters + 1, boosters.count)
        return "Refuerzo \(current)/\(boosters.count)"
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
                HStack(spacing: 6) {
                    SummaryChip(label: "Última", value: lastText, tint: .secondary)
                    SummaryChip(label: "Próxima", value: nextText, tint: hasOverdue ? .red : .secondary)
                    if let boosterChipLabel {
                        SummaryChip(label: boosterChipLabel, value: "", tint: .secondary)
                    }
                }
            }
            Spacer()
        }
    }
}

private struct SummaryChip: View {
    let label: String
    let value: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
        .foregroundStyle(tint)
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
    
    // MARK: - Borrado de serie completa
    func startDeleteSeries(_ summary: PetDetailViewModel.VaccineSeriesSummary) {
        pendingSeriesItems = summary.items
        pendingSeriesCount = summary.items.count
        showingSeriesDeleteDialog = true
    }
    
    func deleteSeries() {
        for vac in pendingSeriesItems {
            NotificationManager.shared.cancelNotification(id: vac.id)
            context.delete(vac)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearSeriesPending()
    }
    
    func clearSeriesPending() {
        pendingSeriesItems = []
        pendingSeriesCount = 0
        showingSeriesDeleteDialog = false
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

#Preview("Solo vencidas") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.onlyOverdueVaccines(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Historial largo") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.longCompletedHistory(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Series mixtas") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.mixedSeriesStates(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Refuerzos y nombres raros") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.weirdNamesAndBoosters(in: container)
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
    
    // Mascota solo con vacunas vencidas pendientes
    @discardableResult
    static func onlyOverdueVaccines(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Rocky", species: .perro, breed: "Boxer", sex: .male)
        ctx.insert(pet)
        let now = Date()
        let v1 = Vaccine(date: now.addingTimeInterval(-7 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Moquillo (dosis 1/2)",
                         manufacturer: "LabX",
                         notes: "No aplicada")
        let v2 = Vaccine(date: now.addingTimeInterval(-20 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Moquillo (dosis 2/2)",
                         manufacturer: nil,
                         notes: "Pendiente")
        ctx.insert(v1)
        ctx.insert(v2)
        try? ctx.save()
        return pet
    }

    // Mascota con historial largo de vacunas completadas (diferentes años)
    @discardableResult
    static func longCompletedHistory(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Daisy", species: .gato, breed: "Persa", sex: .female)
        ctx.insert(pet)
        let now = Date()
        for i in 0..<10 {
            let v = Vaccine(date: Calendar.current.date(byAdding: .year, value: -i, to: now)!,
                            pet: pet,
                            vaccineName: "Triple Felina (dosis \(i+1)/10)",
                            manufacturer: i%2 == 0 ? "FeliVet" : "CatLabs",
                            notes: "Registro anual año \(Calendar.current.component(.year, from: Calendar.current.date(byAdding: .year, value: -i, to: now)!))")
            v.isCompleted = true
            ctx.insert(v)
        }
        try? ctx.save()
        return pet
    }

    // Mascota con varias series activas y estados
    @discardableResult
    static func mixedSeriesStates(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Max", species: .perro, breed: "Labrador", sex: .male)
        ctx.insert(pet)
        let now = Date()
        // Serie 1: En progreso
        let v1 = Vaccine(date: now.addingTimeInterval(-10 * 24 * 3600), pet: pet, vaccineName: "Parvo (dosis 1/3)", manufacturer: "CanVet", notes: nil)
        v1.isCompleted = true
        let v2 = Vaccine(date: now.addingTimeInterval(7 * 24 * 3600), pet: pet, vaccineName: "Parvo (dosis 2/3)", manufacturer: "CanVet", notes: nil)
        // Serie 2: No iniciada
        let v3 = Vaccine(date: now.addingTimeInterval(25 * 24 * 3600), pet: pet, vaccineName: "Leptospirosis (dosis 1/2)", manufacturer: "BioVet", notes: nil)
        // Serie 3: Solo booster
        let v4 = Vaccine(date: now.addingTimeInterval(100 * 24 * 3600), pet: pet, vaccineName: "Rabia (refuerzo)", manufacturer: "Rabix", notes: "Booster anual")
        ctx.insert(v1)
        ctx.insert(v2)
        ctx.insert(v3)
        ctx.insert(v4)
        try? ctx.save()
        return pet
    }

    // Mascota con dosis de refuerzo atípicas y nombres raros
    @discardableResult
    static func weirdNamesAndBoosters(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Nina", species: .gato, breed: "Mestizo", sex: .female)
        ctx.insert(pet)
        let now = Date()
        let v1 = Vaccine(date: now.addingTimeInterval(-2 * 24 * 3600), pet: pet, vaccineName: "Refuerzo Parvovirus", manufacturer: "XLab", notes: nil)
        let v2 = Vaccine(date: now.addingTimeInterval(15 * 24 * 3600), pet: pet, vaccineName: "Moquillo!", manufacturer: nil, notes: "Formato raro")
        let v3 = Vaccine(date: now.addingTimeInterval(50 * 24 * 3600), pet: pet, vaccineName: "Parvo Booster", manufacturer: "ZLabs", notes: "Solo booster")
        ctx.insert(v1)
        ctx.insert(v2)
        ctx.insert(v3)
        try? ctx.save()
        return pet
    }
}
// Seeder para datos demo
struct DemoSeeder {
    /// Inserta la mascota ficticia "DemoDog" con un puñado de medicamentos variados (vencidos, actuales, futuros)
    static func seedDemoDogWithMedications(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let demo = Pet(name: "DemoDog", species: .perro, breed: "Demo Breed", sex: .male)
        ctx.insert(demo)
        let now = Date()
        let cal = Calendar.current
        // Vencidos
        let m1 = Medication(date: cal.date(byAdding: .day, value: -5, to: now)!, pet: demo, name: "Amoxicilina (dosis 1/3)", dosage: "250 mg", frequency: "cada 8 h")
        let m2 = Medication(date: cal.date(byAdding: .day, value: -2, to: now)!, pet: demo, name: "Amoxicilina (dosis 2/3)", dosage: "250 mg", frequency: "cada 8 h")
        // Actual (hoy)
        let m3 = Medication(date: now, pet: demo, name: "Amoxicilina (dosis 3/3)", dosage: "250 mg", frequency: "cada 8 h")
        // Futuros próximos
        let m4 = Medication(date: cal.date(byAdding: .day, value: 2, to: now)!, pet: demo, name: "Prednisona", dosage: "5 mg", frequency: "cada 24 h")
        let m5 = Medication(date: cal.date(byAdding: .day, value: 4, to: now)!, pet: demo, name: "Omeprazol", dosage: "10 mg", frequency: "cada día")
        // Otra serie futura
        let m6 = Medication(date: cal.date(byAdding: .day, value: 6, to: now)!, pet: demo, name: "Cefalexina (dosis 1/2)", dosage: "500 mg", frequency: "cada 12 h")
        let m7 = Medication(date: cal.date(byAdding: .day, value: 8, to: now)!, pet: demo, name: "Cefalexina (dosis 2/2)", dosage: "500 mg", frequency: "cada 12 h")
        ctx.insert(m1); ctx.insert(m2); ctx.insert(m3); ctx.insert(m4); ctx.insert(m5); ctx.insert(m6); ctx.insert(m7)
        try? ctx.save()
        return demo
    }
}


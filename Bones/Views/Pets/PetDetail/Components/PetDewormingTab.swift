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
    
    // Estado de expansión por serie (clave: baseName)
    @State private var expandedSeries: Set<String> = []
    
    // Estado de expansión por subsección dentro de cada serie
    private struct SubsectionsState {
        var next: Bool = true
        var future: Bool = true
        var history: Bool = false
    }
    @State private var expandedSubsections: [String: SubsectionsState] = [:]
    
    // Año de referencia: el de la próxima dosis pendiente (más cercana en el futuro)
    private var referenceYear: Int? {
        let now = Date()
        if let next = viewModel.dewormings.first(where: { $0.date >= now && !$0.isCompleted }) {
            return Calendar.current.component(.year, from: next.date)
        }
        return nil
    }
    
    var body: some View {
        List {
            if viewModel.dewormings.isEmpty {
                ContentUnavailableView("Sin desparasitaciones registradas",
                                       systemImage: "ladybug.fill")
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
                                        DewormingDoseRow(
                                            dew: next,
                                            referenceYear: referenceYear,
                                            allDewormings: summary.items
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
                            
                            // Dosis futuras (pendientes > hoy), excluyendo la "Próxima"
                            let futurePending = summary.items.filter { dew in
                                guard !dew.isCompleted, dew.date > now else { return false }
                                if let next = summary.nextPending {
                                    return dew.id != next.id
                                }
                                return true
                            }
                            
                            if !futurePending.isEmpty {
                                DisclosureGroup(isExpanded: binding.future) {
                                    ForEach(futurePending, id: \.id) { dew in
                                        NavigationLink {
                                            EventDetailView(event: dew)
                                        } label: {
                                            DewormingDoseRow(
                                                dew: dew,
                                                referenceYear: referenceYear,
                                                allDewormings: summary.items
                                            )
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                dew.isCompleted.toggle()
                                                NotificationManager.shared.cancelNotification(id: dew.id)
                                                try? context.save()
                                                viewModel.fetchEvents()
                                            } label: {
                                                Label("Completar", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                startDelete(for: dew)
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
                            
                            // Historial (solo completadas)
                            let history = summary.items.filter { $0.isCompleted }
                            if !history.isEmpty {
                                DisclosureGroup(isExpanded: binding.history) {
                                    ForEach(history, id: \.id) { dew in
                                        NavigationLink {
                                            EventDetailView(event: dew)
                                        } label: {
                                            DewormingDoseRow(
                                                dew: dew,
                                                referenceYear: referenceYear,
                                                allDewormings: summary.items
                                            )
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                dew.isCompleted.toggle()
                                                NotificationManager.shared.cancelNotification(id: dew.id)
                                                try? context.save()
                                                viewModel.fetchEvents()
                                            } label: {
                                                Label("Completar", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                startDelete(for: dew)
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
                            DewormingSeriesRow(summary: summary)
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
    
    // Orden: atrasadas primero, luego por próxima más cercana, luego alfabético
    private var orderedSummaries: [PetDetailViewModel.DewormingSeriesSummary] {
        let now = Date()
        func priority(_ s: PetDetailViewModel.DewormingSeriesSummary) -> (Int, Date?, String) {
            let isOverdue = (s.nextPending?.date ?? now) < now && s.nextPending != nil
            let p0 = isOverdue ? 0 : 1
            let p1 = s.nextPending?.date
            return (p0, p1, s.baseName.lowercased())
        }
        return viewModel.dewormingSeriesSummaries.sorted { a, b in
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
        for s in viewModel.dewormingSeriesSummaries {
            if let next = s.nextPending?.date {
                if next < now || next <= soon { toExpand.insert(s.baseName) }
            }
        }
        expandedSeries = toExpand
    }
    
    // MARK: - Subsections state helpers
    private func ensureSubsectionsState(for summary: PetDetailViewModel.DewormingSeriesSummary) {
        if expandedSubsections[summary.baseName] == nil {
            // Defaults: próxima y futuras abiertas, historial cerrado
            expandedSubsections[summary.baseName] = SubsectionsState(next: true, future: true, history: false)
        }
    }
    
    private func bindingForSubsections(_ baseName: String) -> (next: Binding<Bool>, future: Binding<Bool>, history: Binding<Bool>) {
        if expandedSubsections[baseName] == nil {
            expandedSubsections[baseName] = SubsectionsState()
        }
        return (
            Binding(
                get: { expandedSubsections[baseName, default: SubsectionsState()].next },
                set: { expandedSubsections[baseName, default: SubsectionsState()].next = $0 }
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

// MARK: - Fila de dosis de desparasitación
private struct DewormingDoseRow: View {
    @Bindable var dew: Deworming
    var referenceYear: Int?
    var allDewormings: [Deworming]
    
    var body: some View {
        let numbers = DoseSeries.parseDoseNumbers(from: dew.notes ?? "")
        
        // ¿Está vencida esta dosis? (pendiente y en el pasado)
        let isOverdue = !dew.isCompleted && dew.date < Date()
        
        // Regla de presentación para la línea de dosis:
        // - Primera (0 o 1): "Primera dosis"
        // - Si hay números: "Dosis X/Y"
        // - Si no hay números: no muestra subtítulo, salvo que esté vencida → "Vencida"
        let baseDoseLabel: String? = {
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
        
        let dewYear = Calendar.current.component(.year, from: dew.date)
        let showYear: Bool = {
            guard let ref = referenceYear else { return false }
            return dewYear > ref
        }()
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayBase(from: dew.notes))
                    .fontWeight(.semibold)
                
                if let doseLabelToShow {
                    Text(doseLabelToShow)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                }
                
                HStack(spacing: 4) {
                    Text(dew.date, format: .dateTime.day().month().hour().minute())
                    if showYear {
                        Text("· \(dewYear)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: dew.isCompleted ? "checkmark.circle.fill"
                                              : "ladybug.fill")
                .foregroundStyle(dew.isCompleted ? .green : .accentColor)
        }
    }
    
    private func displayBase(from notes: String?) -> String {
        let raw = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "Desparasitación" }
        // Si las notas vienen con " (dosis X/Y)", usar solo el nombre base
        let base = DoseSeries.splitDoseBase(from: raw)
        // Capitaliza primera letra para mejor presentación
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

// MARK: - Fila de serie
private struct DewormingSeriesRow: View {
    let summary: PetDetailViewModel.DewormingSeriesSummary
    
    private var statusText: String {
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
        case .recurring(let months, let next):
            if let m = months, let d = next {
                return "Recurrente cada \(m) m • \(d.formatted(date: .abbreviated, time: .omitted))"
            } else if let m = months {
                return "Recurrente cada \(m) m"
            } else {
                return "Recurrente"
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
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    LabeledValue(label: "Última", value: lastText)
                    LabeledValue(label: "Próxima", value: nextText)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "ladybug.fill")
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

// MARK: - Resumen de series de desparasitación (similar a Vacunas)
private extension PetDetailViewModel {
    enum DewormingSeriesStatus: Equatable {
        case notStarted
        case inProgress(current: Int, total: Int?)
        case completed
        case recurring(months: Int?, nextDate: Date?)
    }
    
    struct DewormingSeriesSummary: Identifiable {
        let id = UUID()
        let baseName: String
        let items: [Deworming]              // ordenadas por fecha asc
        let lastCompleted: Deworming?
        let nextPending: Deworming?
        let status: DewormingSeriesStatus
        let overdueDays: Int?
    }
    
    var dewormingSeriesSummaries: [DewormingSeriesSummary] {
        let all = dewormings.sorted { $0.date < $1.date }
        // Agrupación: seriesID > rrule > notas normalizadas
        let groups: [String: [Deworming]] = Dictionary(grouping: all) { d in
            if let sid = d.seriesID { return "sid:\(sid.uuidString)" }
            if let rule = d.rrule, !rule.isEmpty { return "rrule:\(rule)" }
            return "notes:\(DoseSeries.normalizeNotes(d.notes))"
        }
        let now = Date()
        
        func daysBetween(_ from: Date, _ to: Date) -> Int {
            let comps = Calendar.current.dateComponents([.day], from: from, to: to)
            return abs(comps.day ?? 0)
        }
        
        func displayBase(from notes: String?) -> String {
            let raw = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { return "Desparasitación" }
            let base = DoseSeries.splitDoseBase(from: raw)
            return base.prefix(1).uppercased() + base.dropFirst()
        }
        
        return groups.values.compactMap { arr in
            let items = arr.sorted { $0.date < $1.date }
            guard let first = items.first else { return nil }
            let baseName = displayBase(from: first.notes)
            let lastCompleted = items.filter { $0.isCompleted }.max(by: { $0.date < $1.date })
            
            // Pendientes futuras y vencidas
            let nextPendingFuture = items
                .filter { !$0.isCompleted && $0.date >= now }
                .min(by: { $0.date < $1.date })
            let pendingPast = items
                .filter { !$0.isCompleted && $0.date < now }
                .sorted { $0.date < $1.date } // ascendente: first = la más antigua vencida
            
            // Selección de “Próxima”:
            // - Si hay vencidas → la más antigua vencida (first)
            // - Si no hay vencidas → la futura más cercana
            let selectedNext: Deworming? = pendingPast.first ?? nextPendingFuture
            
            // OverdueDays coherente con la “Próxima” cuando sea vencida
            let overdueDays: Int? = {
                guard let next = selectedNext, next.date < now else { return nil }
                return daysBetween(next.date, now)
            }()
            
            // Calcular X/Y si las notas traen "(dosis X/Y)"
            let totals = items.compactMap { DoseSeries.parseDoseNumbers(from: $0.notes ?? "").total }
            let totalExpected = totals.max()
            let completedCountByLabel = items
                .filter { $0.isCompleted }
                .compactMap { DoseSeries.parseDoseNumbers(from: $0.notes ?? "").current }
                .max() ?? 0
            let completedCountFallback = items.filter { $0.isCompleted }.count
            let completedCount = max(completedCountByLabel, completedCountFallback)
            
            // Detectar periodicidad mensual aproximada (3 o 6 meses)
            var recurringMonths: Int? = nil
            if items.count >= 2 {
                let sorted = items.sorted { $0.date < $1.date }
                for i in 1..<sorted.count {
                    let interval = sorted[i].date.timeIntervalSince(sorted[i-1].date) / (24*3600)
                    let months = Int((interval / 30.0).rounded())
                    if [3, 6].contains(months) {
                        recurringMonths = months
                        break
                    }
                }
            }
            
            let status: DewormingSeriesStatus = {
                if let total = totalExpected, completedCount >= total, recurringMonths == nil {
                    return .completed
                }
                if let next = selectedNext {
                    if let m = recurringMonths {
                        return .recurring(months: m, nextDate: next.date)
                    } else {
                        return .inProgress(current: max(1, completedCount + 1), total: totalExpected)
                    }
                }
                if completedCount == 0 {
                    return .notStarted
                }
                if let total = totalExpected, completedCount < total {
                    return .inProgress(current: max(1, completedCount + 1), total: total)
                }
                if let m = recurringMonths {
                    return .recurring(months: m, nextDate: nil)
                }
                return .completed
            }()
            
            return DewormingSeriesSummary(
                baseName: baseName,
                items: items,
                lastCompleted: lastCompleted,
                nextPending: selectedNext,
                status: status,
                overdueDays: overdueDays
            )
        }
        // Orden alfabético por baseName por defecto; el orden final lo hace orderedSummaries
        .sorted { $0.baseName.lowercased() < $1.baseName.lowercased() }
    }
}

// MARK: - Previews

#Preview("Desparasitación – Series típicas (CO)") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.seedCommonColombia(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Desparasitación – Vacío") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.emptyPet(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

// Nuevo preview: mismo dataset pero confiando en autoExpand para abrir series relevantes
#Preview("Desparasitación – Expandido (auto)") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.seedCommonColombia(in: container)
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
    
    // Pet con desparasitantes comunes en Colombia y esquemas típicos
    @discardableResult
    static func seedCommonColombia(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        
        let cal = Calendar.current
        let now = Date()
        
        // 1) Drontal Plus — hoy + 15 días (serie 2/2), luego refuerzo a 3 meses
        let seriesDrontal = UUID()
        let dr1 = Deworming(date: now, pet: pet,
                            notes: "Drontal Plus (dosis 1/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesDrontal)
        let dr2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: pet,
                            notes: "Drontal Plus (dosis 2/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesDrontal)
        let drBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                  pet: pet,
                                  notes: "Drontal Plus",
                                  prescriptionImageData: nil,
                                  seriesID: seriesDrontal)
        // Marca la primera como completada si quieres ver “Última” poblada
        dr1.isCompleted = true
        
        // 2) Endogard — hoy + 15 días, luego cada 3 meses
        let seriesEndogard = UUID()
        let en1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!, // pasada
                            pet: pet,
                            notes: "Endogard (dosis 1/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesEndogard)
        en1.isCompleted = false // ← dejamos una vencida para visualizar el estado “Atrasada”
        let en2 = Deworming(date: cal.date(byAdding: .day, value: 5, to: now)!,
                            pet: pet,
                            notes: "Endogard (dosis 2/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesEndogard)
        let enBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                  pet: pet,
                                  notes: "Endogard",
                                  prescriptionImageData: nil,
                                  seriesID: seriesEndogard)
        
        // 3) Panacur (fenbendazol) — 3 días seguidos y repetir el ciclo a los 14 días
        let seriesPanacur = UUID()
        let p1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                           pet: pet,
                           notes: "Panacur (dosis 1/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesPanacur)
        let p2 = Deworming(date: now,
                           pet: pet,
                           notes: "Panacur (dosis 2/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesPanacur)
        let p3 = Deworming(date: cal.date(byAdding: .day, value: 1, to: now)!,
                           pet: pet,
                           notes: "Panacur (dosis 3/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesPanacur)
        // Repetición del ciclo a 14 días
        let pR1 = Deworming(date: cal.date(byAdding: .day, value: 14, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 1/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesPanacur)
        let pR2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 2/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesPanacur)
        let pR3 = Deworming(date: cal.date(byAdding: .day, value: 16, to: now)!,
                            pet: pet,
                            notes: "Panacur (dosis 3/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesPanacur)
        p1.isCompleted = true
        
        // 4) Milbemax — hoy y repetir cada 6 meses
        let seriesMilbemax = UUID()
        let mi1 = Deworming(date: cal.date(byAdding: .day, value: -30, to: now)!,
                            pet: pet,
                            notes: "Milbemax",
                            prescriptionImageData: nil,
                            seriesID: seriesMilbemax)
        mi1.isCompleted = true
        let mi2 = Deworming(date: now,
                            pet: pet,
                            notes: "Milbemax",
                            prescriptionImageData: nil,
                            seriesID: seriesMilbemax)
        let miNext = Deworming(date: cal.date(byAdding: .month, value: 6, to: now)!,
                               pet: pet,
                               notes: "Milbemax",
                               prescriptionImageData: nil,
                               seriesID: seriesMilbemax)
        
        // Insertar
        [dr1, dr2, drBooster,
         en1, en2, enBooster,
         p1, p2, p3, pR1, pR2, pR3,
         mi1, mi2, miNext].forEach { ctx.insert($0) }
        
        try? ctx.save()
        return pet
    }
}

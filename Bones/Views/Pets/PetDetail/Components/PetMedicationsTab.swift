//
//  PetMedicationsTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetMedicationsTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    // Confirmación de borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    @State private var pendingDelete: Medication?
    
    // Confirmación de borrado de serie completa
    @State private var pendingSeriesBase: String?
    @State private var pendingSeriesCount: Int = 0
    @State private var showingSeriesDeleteDialog = false
    
    // Estado de expansión por serie (clave: baseName)
    @State private var expandedSeries: Set<String> = []
    
    // Estado de expansión por subsección dentro de cada serie (incluye "overdue" como en Vacunas)
    private struct SubsectionsState {
        var next: Bool = true
        var overdue: Bool = true
        var future: Bool = true
        var history: Bool = false
    }
    @State private var expandedSubsections: [String: SubsectionsState] = [:]
    
    // Año de referencia: el de la próxima dosis pendiente (más cercana en el futuro)
    private var referenceYear: Int? {
        let now = Date()
        if let next = viewModel.medications.first(where: { $0.date >= now && !$0.isCompleted }) {
            return Calendar.current.component(.year, from: next.date)
        }
        return nil
    }
    
    var body: some View {
        List {
            if viewModel.medications.isEmpty {
                ContentUnavailableView("Sin medicamentos registrados",
                                       systemImage: "pills.fill")
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
                                        MedicationRow(med: next)
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
                            let overduePending = summary.items.filter { med in
                                guard !med.isCompleted, med.date < now else { return false }
                                if let next = summary.nextPending {
                                    return med.id != next.id
                                }
                                return true
                            }
                            if !overduePending.isEmpty {
                                DisclosureGroup(isExpanded: binding.overdue) {
                                    ForEach(overduePending.sorted(by: { $0.date < $1.date }), id: \.id) { med in
                                        NavigationLink {
                                            EventDetailView(event: med)
                                        } label: {
                                            MedicationRow(med: med)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                med.isCompleted.toggle()
                                                NotificationManager.shared.cancelNotification(id: med.id)
                                                try? context.save()
                                                viewModel.fetchEvents()
                                            } label: {
                                                Label("Completar", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                startDelete(for: med)
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
                            let futurePending = summary.items.filter { med in
                                guard !med.isCompleted, med.date > now else { return false }
                                if let next = summary.nextPending {
                                    return med.id != next.id
                                }
                                return true
                            }
                            if !futurePending.isEmpty {
                                DisclosureGroup(isExpanded: binding.future) {
                                    ForEach(futurePending.sorted(by: { $0.date < $1.date }), id: \.id) { med in
                                        NavigationLink {
                                            EventDetailView(event: med)
                                        } label: {
                                            MedicationRow(med: med)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                med.isCompleted.toggle()
                                                NotificationManager.shared.cancelNotification(id: med.id)
                                                try? context.save()
                                                viewModel.fetchEvents()
                                            } label: {
                                                Label("Completar", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                startDelete(for: med)
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
                                    ForEach(history.sorted(by: { $0.date > $1.date }), id: \.id) { med in
                                        NavigationLink {
                                            EventDetailView(event: med)
                                        } label: {
                                            MedicationRow(med: med)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                med.isCompleted.toggle()
                                                NotificationManager.shared.cancelNotification(id: med.id)
                                                try? context.save()
                                                viewModel.fetchEvents()
                                            } label: {
                                                Label("Completar", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                startDelete(for: med)
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
                                MedicationSeriesRow(summary: summary)
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
                    if let med = pendingDelete { deleteSingle(med) }
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    if let med = pendingDelete { deleteSingle(med) }
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
                if let base = pendingSeriesBase {
                    deleteSeries(baseName: base)
                }
            }
            Button("Cancelar", role: .cancel) { clearSeriesPending() }
        } message: {
            Text("Se eliminarán todas las dosis de esta serie. Esta acción no se puede deshacer.")
        }
    }
    
    // Orden: atrasadas primero, luego por próxima más cercana, luego alfabético
    private var orderedSummaries: [PetDetailViewModel.MedicationSeriesSummary] {
        let now = Date()
        func priority(_ s: PetDetailViewModel.MedicationSeriesSummary) -> (Int, Date?, String) {
            let isOverdue = (s.nextPending?.date ?? now) < now && s.nextPending != nil
            let p0 = isOverdue ? 0 : 1
            let p1 = s.nextPending?.date
            return (p0, p1, s.baseName.lowercased())
        }
        return viewModel.medicationSeriesSummaries.sorted { a, b in
            let pa = priority(a), pb = priority(b)
            if pa.0 != pb.0 { return pa.0 < pb.0 }
            if pa.1 != pb.1 { return (pa.1 ?? .distantFuture) < (pb.1 ?? .distantFuture) }
            return pa.2 < pb.2
        }
    }
    
    private func autoExpandCriticalSeries() {
        let now = Date()
        let soon = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        var toExpand: Set<String> = expandedSeries
        for s in viewModel.medicationSeriesSummaries {
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
                if expandedSubsections[s.baseName] == nil {
                    expandedSubsections[s.baseName] = SubsectionsState(next: true, overdue: true, future: true, history: false)
                } else if hasOverdue {
                    expandedSubsections[s.baseName]?.overdue = true
                }
            }
        }
        expandedSeries = toExpand
    }
    
    // MARK: - Subsections state helpers
    private func ensureSubsectionsState(for summary: PetDetailViewModel.MedicationSeriesSummary) {
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

// MARK: - Fila
private struct MedicationRow: View {
    @Bindable var med: Medication            // Bindable para reflejar cambios en línea
    @Environment(\.modelContext) private var context
    
    var body: some View {
        let parsed = DoseSeries.splitDose(from: med.name)
        
        // Normalizamos espacios en blanco
        let dosageText = med.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        // Preferimos la frecuencia inferida; si no se puede, usamos la guardada (fallback)
        let inferred = inferredFrequency(for: med)
        let frequencyText = inferred?.trimmingCharacters(in: .whitespacesAndNewlines)
                           ?? med.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        // Transformamos “Dosis X/Y” -> “Toma X/Y” para evitar confusión con la cantidad
        let rawDoseSuffix = parsed.dose.map { $0.replacingOccurrences(of: "Dosis", with: "Toma") }
        
        // Estado de vencimiento
        let isOverdue = (!med.isCompleted && med.date < Date())
        // Si hay etiqueta de toma, le añadimos "(Vencida)"; si no, mostraremos una línea aparte
        let doseSuffix: String? = {
            guard let s = rawDoseSuffix else { return nil }
            return isOverdue ? "\(s) (Vencida)" : s
        }()
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Nombre del medicamento (sin el sufijo de dosis)
                Text(parsed.base).fontWeight(.semibold)
                
                // Línea compacta: cantidad · frecuencia · Toma X/Y [(Vencida)]
                let parts: [String] = {
                    var items: [String] = []
                    if !dosageText.isEmpty { items.append(dosageText) }
                    if !frequencyText.isEmpty { items.append(frequencyText) }
                    if let doseSuffix { items.append(doseSuffix) }
                    if items.isEmpty { items = ["Dosis no asignada"] }
                    return items
                }()
                
                Text(parts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
                
                // Si no había etiqueta de toma pero está vencida, mostramos “Vencida” en una línea aparte
                if rawDoseSuffix == nil && isOverdue {
                    Text("Vencida")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                // Fecha y hora
                Text(med.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: med.isCompleted ? "checkmark.circle.fill"
                                              : "pills.circle")
                .foregroundStyle(med.isCompleted ? .green : .accentColor)
        }
    }
    
    // MARK: - Frecuencia inferida
    private func inferredFrequency(for med: Medication) -> String? {
        // 1) Si hubiera una rrule válida, podríamos formatearla aquí.
        if let rule = med.rrule, let fromRule = format(rrule: rule) {
            return fromRule
        }
        
        // 2) Inferir a partir del intervalo entre tomas de la misma serie
        guard let petID = med.pet?.id else { return nil }
        let base = DoseSeries.splitDoseBase(from: med.name)
        
        // Traer todos los meds de esa mascota (rápido: pocos objetos)
        let predicate = #Predicate<Medication> { $0.pet?.id == petID }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        let siblings = fetched.filter { DoseSeries.splitDoseBase(from: $0.name) == base }
                              .sorted { $0.date < $1.date }
        guard !siblings.isEmpty else { return nil }
        
        // Buscar el siguiente (o anterior) relativo a este med
        if let idx = siblings.firstIndex(where: { $0.id == med.id }) {
            // Preferimos el siguiente
            if idx + 1 < siblings.count {
                let interval = siblings[idx + 1].date.timeIntervalSince(med.date)
                if interval > 0 { return format(interval: interval) }
            }
            // Si no hay siguiente, usamos el anterior
            if idx > 0 {
                let interval = med.date.timeIntervalSince(siblings[idx - 1].date)
                if interval > 0 { return format(interval: interval) }
            }
        } else {
            // Si por alguna razón no encontramos el índice (p. ej. sin guardar),
            // intentamos la diferencia con el más cercano en fecha
            if let nearest = siblings.min(by: { abs($0.date.timeIntervalSince(med.date)) < abs($1.date.timeIntervalSince(med.date)) }) {
                let interval = abs(nearest.date.timeIntervalSince(med.date))
                if interval > 0 { return format(interval: interval) }
            }
        }
        return nil
    }
    
    // Intenta formatear algunas RRULE simples (HOURLY/DAILY/WEEKLY/MONTHLY con INTERVAL)
    private func format(rrule: String) -> String? {
        // Muy básico: extrae FREQ e INTERVAL
        // Ej.: "FREQ=HOURLY;INTERVAL=8"
        let parts = rrule
            .split(separator: ";")
            .map { $0.split(separator: "=").map(String.init) }
            .reduce(into: [String: String]()) { dict, kv in
                if kv.count == 2 { dict[kv[0].uppercased()] = kv[1].uppercased() }
            }
        guard let freq = parts["FREQ"] else { return nil }
        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        
        switch freq {
        case "HOURLY":
            return "cada \(interval) h"
        case "DAILY":
            return interval == 1 ? "cada día" : "cada \(interval) días"
        case "WEEKLY":
            return interval == 1 ? "cada semana" : "cada \(interval) semanas"
        case "MONTHLY":
            return interval == 1 ? "cada mes" : "cada \(interval) meses"
        default:
            return nil
        }
    }
    
    // Convierte un intervalo a una frase “cada X …” con redondeo razonable
    private func format(interval: TimeInterval) -> String {
        let hour: Double = 3600
        let day: Double = 24 * hour
        let week: Double = 7 * day
        let month: Double = 30 * day
        
        if interval < 1.5 * day {
            // Redondeo a horas típicas
            let hours = interval / hour
            let canonical: [Double] = [4, 6, 8, 12, 24]
            let nearest = canonical.min(by: { abs($0 - hours) < abs($1 - hours) }) ?? round(hours)
            let h = Int(nearest.rounded())
            return h == 24 ? "cada día" : "cada \(h) h"
        } else if interval < 2 * week {
            let days = Int((interval / day).rounded())
            return days == 1 ? "cada día" : "cada \(days) días"
        } else if interval < 2 * month {
            let weeks = Int((interval / week).rounded())
            return weeks <= 1 ? "cada semana" : "cada \(weeks) semanas"
        } else {
            let months = Int((interval / month).rounded())
            return months <= 1 ? "cada mes" : "cada \(months) meses"
        }
    }
}

// MARK: - Fila de serie (encabezado)
private struct MedicationSeriesRow: View {
    let summary: PetDetailViewModel.MedicationSeriesSummary
    
    // Detectar si hay dosis vencidas pendientes en la serie
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
            Image(systemName: "pills.fill")
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
private extension PetMedicationsTab {
    func startDelete(for med: Medication) {
        // Cuenta cuántas futuras hay en la misma serie (incluye la actual)
        let count = max(0, DoseSeries.futureMedications(from: med, in: context).count - 1)
        if count == 0 {
            deleteSingle(med)
        } else {
            pendingDelete = med
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    func deleteSingle(_ med: Medication) {
        NotificationManager.shared.cancelNotification(id: med.id)
        context.delete(med)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }
    
    func deleteThisAndFuture() {
        guard let med = pendingDelete else { return }
        let all = DoseSeries.futureMedications(from: med, in: context)
        for m in all {
            NotificationManager.shared.cancelNotification(id: m.id)
            context.delete(m)
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
    func startDeleteSeries(_ summary: PetDetailViewModel.MedicationSeriesSummary) {
        pendingSeriesBase = summary.baseName
        pendingSeriesCount = summary.items.count
        showingSeriesDeleteDialog = true
    }
    
    func deleteSeries(baseName: String) {
        let all = viewModel.medications.filter { DoseSeries.splitDoseBase(from: $0.name) == baseName }
        for med in all {
            NotificationManager.shared.cancelNotification(id: med.id)
            context.delete(med)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearSeriesPending()
    }
    
    func clearSeriesPending() {
        pendingSeriesBase = nil
        pendingSeriesCount = 0
        showingSeriesDeleteDialog = false
    }
}

// MARK: - Previews

private enum PetMedicationsPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}

#Preview("MedTab – Sin dosis") {
    let container = PetMedicationsPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    // Mascota
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    // Medicamentos SIN sufijo de serie (no muestran “Toma X/Y”)
    let m1 = Medication(date: Date().addingTimeInterval(3600),
                        pet: pet,
                        name: "Amoxicilina",
                        dosage: "250 mg",
                        frequency: "cada 8 h")
    let m2 = Medication(date: Date().addingTimeInterval(6*3600),
                        pet: pet,
                        name: "Omeprazol",
                        dosage: "20 mg",
                        frequency: "cada 24 h")
    ctx.insert(m1)
    ctx.insert(m2)
    try? ctx.save()
    
    // ViewModel e inyección del MISMO context
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ctx)
    
    return NavigationStack {
        PetMedicationsTab(viewModel: vm)
    }
    .modelContext(ctx)
}

#Preview("MedTab – Una sola dosis (1/1)") {
    let container = PetMedicationsPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    
    // Medicamento con una sola toma (1/1)
    let m = Medication(date: Date().addingTimeInterval(2*3600),
                       pet: pet,
                       name: "Doxiciclina (dosis 1/1)",
                       dosage: "50 mg",
                       frequency: "cada 12 h")
    ctx.insert(m)
    try? ctx.save()
    
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ctx)
    
    return NavigationStack {
        PetMedicationsTab(viewModel: vm)
    }
    .modelContext(ctx)
}

#Preview("MedTab – Varias dosis (1/3, 2/3, 3/3)") {
    let container = PetMedicationsPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Bobby", species: .perro, breed: "Mestizo", sex: .male)
    ctx.insert(pet)
    
    // Serie de varias tomas del mismo medicamento
    let base = "Amoxicilina"
    let m1 = Medication(date: Date().addingTimeInterval(1*3600),
                        pet: pet,
                        name: "\(base) (dosis 1/3)",
                        dosage: "250 mg",
                        frequency: "")
    let m2 = Medication(date: Date().addingTimeInterval(9*3600),
                        pet: pet,
                        name: "\(base) (dosis 2/3)",
                        dosage: "250 mg",
                        frequency: "")
    let m3 = Medication(date: Date().addingTimeInterval(17*3600),
                        pet: pet,
                        name: "\(base) (dosis 3/3)",
                        dosage: "250 mg",
                        frequency: "")
    ctx.insert(m1)
    ctx.insert(m2)
    ctx.insert(m3)
    try? ctx.save()
    
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ctx)
    
    return NavigationStack {
        PetMedicationsTab(viewModel: vm)
    }
    .modelContext(ctx)
}

#Preview("MedTab – Escenario complejo") {
    let container = PetMedicationsPreviewData.makeContainer()
    let ctx = ModelContext(container)
    let cal = Calendar.current
    let now = Date()
    
    // Mascota única para el escenario
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    // Helpers de fecha
    func at(hour: Int, minute: Int, on base: Date) -> Date {
        var comps = cal.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        return cal.date(from: comps) ?? base
    }
    let today = now
    let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    
    // 1) Unidosis futuro
    let omep = Medication(
        date: at(hour: 20, minute: 0, on: tomorrow),
        pet: pet,
        name: "Omeprazol",
        dosage: "10 mg",
        frequency: "cada día"
    )
    
    // 2) Serie Amoxicilina (5 dosis) mezclando pasadas y futuras
    //    1/5 ayer 22:00 (pasada), 2/5 hoy 06:00 (pasada), 3/5 hoy 14:00 (futura),
    //    4/5 hoy 22:00 (futura), 5/5 mañana 06:00 (futura)
    let amoxBase = "Amoxicilina"
    let amox1 = Medication(date: at(hour: 22, minute: 0, on: yesterday), pet: pet,
                           name: "\(amoxBase) (dosis 1/5)", dosage: "250 mg", frequency: "cada 8 h")
    let amox2 = Medication(date: at(hour: 6, minute: 0, on: today), pet: pet,
                           name: "\(amoxBase) (dosis 2/5)", dosage: "250 mg", frequency: "cada 8 h")
    let amox3 = Medication(date: at(hour: 14, minute: 0, on: today), pet: pet,
                           name: "\(amoxBase) (dosis 3/5)", dosage: "250 mg", frequency: "")
    let amox4 = Medication(date: at(hour: 22, minute: 0, on: today), pet: pet,
                           name: "\(amoxBase) (dosis 4/5)", dosage: "250 mg", frequency: "")
    let amox5 = Medication(date: at(hour: 6, minute: 0, on: tomorrow), pet: pet,
                           name: "\(amoxBase) (dosis 5/5)", dosage: "250 mg", frequency: "")
    // Marca la 2/5 como completada para probar el check
    amox2.isCompleted = true
    amox2.completedAt = now
    
    // 3) Otra serie con vencidas
    let predBase = "Prednisona"
    let p1 = Medication(date: at(hour: 9, minute: 0, on: yesterday), pet: pet,
                        name: "\(predBase) (dosis 1/3)", dosage: "5 mg", frequency: "cada día")
    let p2 = Medication(date: at(hour: 9, minute: 0, on: today), pet: pet,
                        name: "\(predBase) (dosis 2/3)", dosage: "5 mg", frequency: "cada día")
    let p3 = Medication(date: at(hour: 9, minute: 0, on: tomorrow), pet: pet,
                        name: "\(predBase) (dosis 3/3)", dosage: "5 mg", frequency: "cada día")
    
    // 4) Vitamina con RRULE (para probar inferencia desde la regla)
    let b12 = Medication(date: at(hour: 18, minute: 0, on: tomorrow), pet: pet,
                         name: "Vitamina B12",
                         dosage: "1 ml",
                         frequency: "",
                         notes: "Suplemento")
    b12.rrule = "FREQ=DAILY;INTERVAL=2" // debería mostrar “cada 2 días”
    
    // Insertar todo
    [omep, amox1, amox2, amox3, amox4, amox5, p1, p2, p3, b12].forEach { ctx.insert($0) }
    try? ctx.save()
    
    // VM e inyección del mismo contexto
    let vm = PetDetailViewModel(petID: pet.id)
    vm.inject(context: ctx)
    
    return NavigationStack {
        PetMedicationsTab(viewModel: vm)
    }
    .modelContext(ctx)
}

// MARK: - Resumen de series de medicamentos (similar a Vacunas)
private extension PetDetailViewModel {
    enum MedicationSeriesStatus: Equatable {
        case notStarted
        case inProgress(current: Int, total: Int?)
        case completed
    }
    
    struct MedicationSeriesSummary: Identifiable {
        let id = UUID()
        let baseName: String
        let items: [Medication]              // ordenadas por fecha asc
        let lastCompleted: Medication?
        let nextPending: Medication?
        let status: MedicationSeriesStatus
        let overdueDays: Int?
    }
    
    var medicationSeriesSummaries: [MedicationSeriesSummary] {
        let all = medications.sorted { $0.date < $1.date }
        let groups = Dictionary(grouping: all) { DoseSeries.splitDoseBase(from: $0.name) }
        let now = Date()
        
        func daysBetween(_ from: Date, _ to: Date) -> Int {
            let comps = Calendar.current.dateComponents([.day], from: from, to: to)
            return abs(comps.day ?? 0)
        }
        
        return groups.keys.sorted().compactMap { base in
            let items = (groups[base] ?? []).sorted { $0.date < $1.date }
            guard !items.isEmpty else { return nil }
            
            let lastCompleted = items.filter { $0.isCompleted }.max(by: { $0.date < $1.date })
            
            // Pendientes
            let futurePending = items
                .filter { !$0.isCompleted && $0.date >= now }
                .min(by: { $0.date < $1.date })
            let overduePendingAsc = items
                .filter { !$0.isCompleted && $0.date < now }
                .sorted { $0.date < $1.date }
            
            // Selección de “Próxima”: si hay vencidas, toma la más antigua; si no, la futura más cercana
            let selectedNext: Medication? = overduePendingAsc.first ?? futurePending
            
            let overdueDays: Int? = {
                guard let next = selectedNext, next.date < now else { return nil }
                return daysBetween(next.date, now)
            }()
            
            // X/Y esperado
            let totals = items.compactMap { DoseSeries.parseDoseNumbers(from: $0.name).total }
            let totalExpected = totals.max()
            let completedCountByLabel = items
                .filter { $0.isCompleted }
                .compactMap { DoseSeries.parseDoseNumbers(from: $0.name).current }
                .max() ?? 0
            let completedCountFallback = items.filter { $0.isCompleted }.count
            let completedCount = max(completedCountByLabel, completedCountFallback)
            
            let status: MedicationSeriesStatus = {
                if let total = totalExpected, completedCount >= total {
                    return .completed
                }
                if selectedNext != nil {
                    return .inProgress(current: max(1, completedCount + 1), total: totalExpected)
                }
                if completedCount == 0 {
                    return .notStarted
                }
                if let total = totalExpected, completedCount < total {
                    return .inProgress(current: max(1, completedCount + 1), total: total)
                }
                return .completed
            }()
            
            return MedicationSeriesSummary(
                baseName: base,
                items: items,
                lastCompleted: lastCompleted,
                nextPending: selectedNext,
                status: status,
                overdueDays: overdueDays
            )
        }
    }
}

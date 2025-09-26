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
    
    var body: some View {
        List {
            if viewModel.medications.isEmpty {
                ContentUnavailableView("Sin medicamentos registrados",
                                       systemImage: "pills.fill")
            } else {
                ForEach(viewModel.medications, id: \.id) { med in
                    NavigationLink {
                        EventDetailView(event: med)
                    } label: {
                        MedicationRow(med: med)
                    }
                    // Swipe: completar
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
                    // Swipe: borrar (con confirmación de serie)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            startDelete(for: med)
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }   // refresca si usas propiedad @Published
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
        let doseSuffix = parsed.dose.map { $0.replacingOccurrences(of: "Dosis", with: "Toma") }
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Nombre del medicamento (sin el sufijo de dosis)
                Text(parsed.base).fontWeight(.semibold)
                
                // Línea compacta: cantidad · frecuencia · Toma X/Y
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
                    .foregroundStyle(.secondary)
                
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

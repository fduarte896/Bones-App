//  EventDetailView.swift
//  Bones

import SwiftUI
import SwiftData
import PhotosUI

struct EventDetailView: View {
    let event: any BasicEvent
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // Borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    
    var body: some View {
        Group {
            switch event {
            case let med as Medication:
                MedicationDetailView(med: med) {
                    startDelete(for: med)
                }
            case let vac as Vaccine:
                VaccineDetailView(vac: vac) {
                    startDelete(for: vac)
                }
            case let dew as Deworming:
                DewormingDetailView(dew: dew) {
                    startDelete(for: dew)
                }
            case let groom as Grooming:
                GroomingDetailView(groom: groom) {
                    deleteSingle(event: groom)
                }
            case let weight as WeightEntry:
                WeightEntryDetailView(weight: weight) {
                    deleteSingle(event: weight)
                }
            default:
                Text("Tipo de evento no soportado.")
            }
        }
        .navigationTitle(event.displayType.isEmpty ? "Detalle" : event.displayType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(event.isCompleted ? "Desmarcar" : "Completar") {
                    toggleCompleted()
                }
            }
        }
        // Confirmación de borrado en serie cuando aplique
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
                    deleteSingle(event: event)
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    deleteSingle(event: event)
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

// MARK: - Toolbar actions
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
    
    func startDelete(for med: Medication) {
        let count = max(0, DoseSeries.futureMedications(from: med, in: context).count - 1)
        if count == 0 {
            deleteSingle(event: med)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    func startDelete(for vac: Vaccine) {
        let count = max(0, DoseSeries.futureVaccines(from: vac, in: context).count - 1)
        if count == 0 {
            deleteSingle(event: vac)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    func startDelete(for dew: Deworming) {
        let count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
        if count == 0 {
            deleteSingle(event: dew)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    func deleteThisAndFuture() {
        switch event {
        case let med as Medication:
            for m in DoseSeries.futureMedications(from: med, in: context) {
                NotificationManager.shared.cancelNotification(id: m.id)
                context.delete(m)
            }
        case let vac as Vaccine:
            for v in DoseSeries.futureVaccines(from: vac, in: context) {
                NotificationManager.shared.cancelNotification(id: v.id)
                context.delete(v)
            }
        case let dew as Deworming:
            for d in DoseSeries.futureDewormings(from: dew, in: context) {
                NotificationManager.shared.cancelNotification(id: d.id)
                context.delete(d)
            }
        default:
            break
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

// MARK: - Sub‑vistas tipadas

private struct MedicationDetailView: View {
    @Bindable var med: Medication
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    // MARK: – Añadir próximas dosis (estado local)
    private enum ScheduleMode: String, CaseIterable, Identifiable {
        case interval, perDay
        var id: Self { self }
        var label: String { self == .interval ? "Por intervalo" : "Por día" }
    }
    private enum IntervalUnit: String, CaseIterable, Identifiable {
        case hours, days, weeks, months
        var id: Self { self }
        var label: String {
            switch self {
            case .hours:  "horas"
            case .days:   "días"
            case .weeks:  "semanas"
            case .months: "meses"
            }
        }
    }
    
    @State private var scheduleMode: ScheduleMode = .interval
    @State private var intervalValue: Int = 8
    @State private var intervalUnit: IntervalUnit = .hours
    @State private var timesPerDay: Int = 3
    @State private var durationDays: Int = 1
    @State private var isAdding = false
    @State private var infoText: String?
    
    var body: some View {
        Form {
            Header(pet: med.pet, title: med.name, icon: "pills.fill", isCompleted: med.isCompleted, date: med.date)
            
            Section("Información") {
                TextField("Nombre", text: $med.name)
                    .onChange(of: med.name) { _, _ in save() }
                TextField("Dosis", text: $med.dosage)
                    .onChange(of: med.dosage) { _, _ in save() }
                
                // Frecuencia inferida (solo lectura)
                let fallback = med.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
                let inferred = inferredFrequency(for: med)
                let display = inferred ?? (fallback.isEmpty ? "No determinada" : fallback)
                LabeledContent("Frecuencia") {
                    Text(display).foregroundStyle(.secondary)
                }
                Text("Se infiere automáticamente a partir de la programación.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $med.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: med.date) { _, _ in reschedule(for: med) }
            }
            
            // MARK: – Nueva sección: Añadir próximas dosis
            Section("Añadir próximas dosis") {
                // Acción simple: una sola dosis extra, basada en serie/frecuencia (no depende de controles)
                if let next = suggestedNextDoseDate() {
                    LabeledContent("Siguiente dosis") {
                        Text(next.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Siguiente sugerida") {
                        Text("No determinada · se usará +8 h")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    Task { await addNextDoseSmart() }
                } label: {
                    Label(isAdding ? "Añadiendo…" : "Añadir siguiente dosis", systemImage: "plus.circle")
                }
                .disabled(isAdding)
                
                // Controles avanzados para series (cuando quieren varias)

            }
            
            Section ("Añadir otras dosis") {
                Picker("Modo", selection: $scheduleMode) {
                    ForEach(ScheduleMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                
                if scheduleMode == .interval {
                    IntervalRow(value: $intervalValue, unit: $intervalUnit)
                    Stepper("Durante \(durationDays) día(s)", value: $durationDays, in: 1...90)
                    
                    if let summary = intervalSummary(
                        start: med.date,
                        durationDays: durationDays,
                        stepValue: intervalValue,
                        stepUnit: intervalUnit
                    ) {
                        Text("Se crearán \(summary.total) dosis en total (incluida la actual). Última: \(summary.last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Stepper("\(timesPerDay) × por día", value: $timesPerDay, in: 1...12)
                    Stepper("Durante \(durationDays) día(s)", value: $durationDays, in: 1...30)
                }
                
                if let preview = medicationPreview(
                    start: med.date,
                    mode: scheduleMode,
                    intervalValue: intervalValue,
                    intervalUnit: intervalUnit,
                    durationDays: durationDays,
                    timesPerDay: timesPerDay
                ), preview.count > 1 {
                    MedicationPreviewView(dates: preview)
                        .padding(.top, 4)
                }
                
                HStack {
                    Spacer()
                    Button {
                        Task { await addSeries() }
                    } label: {
                        Label(isAdding ? "Añadiendo…" : "Añadir serie", systemImage: "calendar.badge.plus")
                    }
                    .disabled(isAdding)
                }
                
                if let infoText, !infoText.isEmpty {
                    Text(infoText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($med.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: med.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $med.prescriptionImageData) {
                // Propaga a toda la serie (pasado y futuro)
                let newData = med.prescriptionImageData
                propagatePrescriptionForMedication(med, with: newData, in: context)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
    
    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
    
    // MARK: - Inferencia y parsing de frecuencia
    private func inferredFrequency(for med: Medication) -> String? {
        if let rule = med.rrule, let fromRule = format(rrule: rule) {
            return fromRule
        }
        guard let petID = med.pet?.id else { return nil }
        let base = DoseSeries.splitDoseBase(from: med.name)
        
        let predicate = #Predicate<Medication> { $0.pet?.id == petID }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        let siblings = fetched.filter { DoseSeries.splitDoseBase(from: $0.name) == base }
                              .sorted { $0.date < $1.date }
        guard !siblings.isEmpty else { return nil }
        
        if let idx = siblings.firstIndex(where: { $0.id == med.id }) {
            if idx + 1 < siblings.count {
                let interval = siblings[idx + 1].date.timeIntervalSince(med.date)
                if interval > 0 { return format(interval: interval) }
            }
            if idx > 0 {
                let interval = med.date.timeIntervalSince(siblings[idx - 1].date)
                if interval > 0 { return format(interval: interval) }
            }
        } else if let nearest = siblings.min(by: {
            abs($0.date.timeIntervalSince(med.date)) < abs($1.date.timeIntervalSince(med.date))
        }) {
            let interval = abs(nearest.date.timeIntervalSince(med.date))
            if interval > 0 { return format(interval: interval) }
        }
        return nil
    }
    
    private func format(rrule: String) -> String? {
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
    
    private func format(interval: TimeInterval) -> String {
        let hour: Double = 3600
        let day: Double = 24 * hour
        let week: Double = 7 * day
        let month: Double = 30 * day
        
        if interval < 1.5 * day {
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
    
    // Convierte “cada X …” a segundos
    private func parseFrequencyToInterval(_ freq: String) -> TimeInterval? {
        let lower = freq.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "cada día" { return 24 * 3600 }
        if lower == "cada semana" { return 7 * 24 * 3600 }
        if lower == "cada mes" { return 30 * 24 * 3600 }
        let parts = lower.split(separator: " ")
        if parts.count >= 3, parts[0] == "cada", let value = Double(parts[1]) {
            let unitStr = parts[2]
            if unitStr.hasPrefix("h") { return value * 3600 }
            if unitStr.hasPrefix("d") { return value * 24 * 3600 }
            if unitStr.hasPrefix("semana") { return value * 7 * 24 * 3600 }
            if unitStr.hasPrefix("mes") { return value * 30 * 24 * 3600 }
        }
        return nil
    }
    
    // MARK: - Siguiente dosis sugerida (independiente de controles)
    private func suggestedNextDoseDate() -> Date? {
        guard let petID = med.pet?.id else { return nil }
        let base = DoseSeries.splitDoseBase(from: med.name)
        
        // Todos los hermanos por fecha ascendente
        let all = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let siblings = all
            .filter { $0.pet?.id == petID && DoseSeries.splitDoseBase(from: $0.name) == base }
            .sorted { $0.date < $1.date }
        guard let last = siblings.last else { return nil }
        
        // 1) Si hay al menos 2, usar intervalo entre las dos últimas
        if siblings.count >= 2 {
            let prev = siblings[siblings.count - 2]
            let delta = last.date.timeIntervalSince(prev.date)
            if delta > 0 {
                return last.date.addingTimeInterval(delta)
            }
        }
        // 2) Si solo hay una, intenta parsear frecuencia guardada o inferida
        let freqStr = med.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = parseFrequencyToInterval(freqStr), seconds > 0 {
            return last.date.addingTimeInterval(seconds)
        }
        if let inferred = inferredFrequency(for: med),
           let seconds = parseFrequencyToInterval(inferred), seconds > 0 {
            return last.date.addingTimeInterval(seconds)
        }
        // 3) Fallback: +8 h
        return last.date.addingTimeInterval(8 * 3600)
    }
    
    // MARK: - Helpers de programación (locales a esta vista)
    private func addInterval(_ value: Int, unit: IntervalUnit, to date: Date) -> Date {
        let cal = Calendar.current
        switch unit {
        case .hours:  return cal.date(byAdding: .hour,  value: value, to: date) ?? date
        case .days:   return cal.date(byAdding: .day,   value: value, to: date) ?? date
        case .weeks:  return cal.date(byAdding: .day,   value: 7 * value, to: date) ?? date
        case .months: return cal.date(byAdding: .month, value: value, to: date) ?? date
        }
    }
    
    private func medicationPreview(start: Date,
                                   mode: ScheduleMode,
                                   intervalValue: Int,
                                   intervalUnit: IntervalUnit,
                                   durationDays: Int,
                                   timesPerDay: Int) -> [Date]? {
        let cal = Calendar.current
        switch mode {
        case .interval:
            let end = cal.date(byAdding: .day, value: durationDays, to: start) ?? start
            var dates: [Date] = [start]
            var current = start
            while true {
                let next = addInterval(intervalValue, unit: intervalUnit, to: current)
                if next > end { break }
                dates.append(next)
                current = next
            }
            return dates
        case .perDay:
            let total = max(1, timesPerDay * durationDays)
            let stepHours = Int((24.0 / max(1.0, Double(timesPerDay))).rounded())
            var dates: [Date] = [start]
            var current = start
            if total > 1 {
                for _ in 1..<total {
                    current = cal.date(byAdding: .hour, value: stepHours, to: current) ?? current
                    dates.append(current)
                }
            }
            return dates
        }
    }
    
    private func intervalSummary(start: Date,
                                 durationDays: Int,
                                 stepValue: Int,
                                 stepUnit: IntervalUnit) -> (total: Int, last: Date)? {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: durationDays, to: start) ?? start
        var current = start
        var last = start
        var count = 1
        while true {
            let next = addInterval(stepValue, unit: stepUnit, to: current)
            if next > end { break }
            last = next
            count += 1
            current = next
        }
        return (count, last)
    }
    
    // MARK: - Inserción y utilidades de serie
    private func existsMedication(petID: UUID, baseName: String, date: Date) -> Bool {
        let predicate = #Predicate<Medication> { m in
            m.pet?.id == petID && m.date == date
        }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        return fetched.contains { DoseSeries.splitDoseBase(from: $0.name) == baseName }
    }
    
    private func scheduleNotification(for med: Medication) {
        let title = "Medicamento"
        let body = "\(med.pet?.name ?? "") – \(med.name)"
        NotificationManager.shared.scheduleNotification(id: med.id, title: title, body: body, fireDate: med.date, advance: 0)
    }
    
    private func relabelSeries(base: String, siblings: [Medication]) {
        // Reetiqueta todos como "(dosis i/N)" en orden cronológico ascendente
        let sorted = siblings.sorted { $0.date < $1.date }
        let total = sorted.count
        for (i, item) in sorted.enumerated() {
            let label = "dosis \(i + 1)/\(total)"
            item.name = "\(base) (\(label))"
        }
    }
    
    // Añadir una sola próxima dosis basada en la serie/frecuencia (intuitivo)
    @MainActor
    private func addNextDoseSmart() async {
        guard let pet = med.pet, let petID = pet.id as UUID? else { return }
        isAdding = true
        defer { isAdding = false }
        
        // Calcular próxima fecha sugerida
        let next = suggestedNextDoseDate() ?? med.date.addingTimeInterval(8 * 3600)
        
        let base = DoseSeries.splitDoseBase(from: med.name)
        if existsMedication(petID: petID, baseName: base, date: next) {
            infoText = "Ya existe una dosis en la fecha sugerida."
            return
        }
        
        // Reunir hermanos actuales
        let allForPet = (try? context.fetch(FetchDescriptor<Medication>()))?.filter { $0.pet?.id == petID } ?? []
        var siblings = allForPet.filter { DoseSeries.splitDoseBase(from: $0.name) == base }
        
        // Insertar nueva
        let newMed = Medication(date: next,
                                pet: pet,
                                name: base, // temporal, reetiquetamos abajo
                                dosage: med.dosage,
                                frequency: med.frequency,
                                notes: med.notes,
                                prescriptionImageData: med.prescriptionImageData)
        context.insert(newMed)
        siblings.append(newMed)
        
        // Reetiquetar toda la serie (incluida la actual) como dosis i/N
        relabelSeries(base: base, siblings: siblings)
        
        scheduleNotification(for: newMed)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        infoText = "Se añadió la siguiente dosis."
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    @MainActor
    private func addSeries() async {
        guard let pet = med.pet, let petID = pet.id as UUID? else { return }
        isAdding = true
        defer { isAdding = false }
        
        // Genera previsualización (incluye la actual)
        let preview = medicationPreview(start: med.date,
                                        mode: scheduleMode,
                                        intervalValue: intervalValue,
                                        intervalUnit: intervalUnit,
                                        durationDays: durationDays,
                                        timesPerDay: timesPerDay) ?? [med.date]
        // Omitimos la primera (es la actual); el resto serán nuevas
        let newDates = Array(preview.dropFirst())
        if newDates.isEmpty {
            infoText = "No hay fechas adicionales que añadir."
            return
        }
        
        let base = DoseSeries.splitDoseBase(from: med.name)
        let allForPet = (try? context.fetch(FetchDescriptor<Medication>()))?.filter { $0.pet?.id == petID } ?? []
        var siblings = allForPet.filter { DoseSeries.splitDoseBase(from: $0.name) == base }
        
        // Evita duplicados y acumula las que sí se insertan
        var inserted: [Medication] = []
        for d in newDates {
            if !existsMedication(petID: petID, baseName: base, date: d) {
                let m = Medication(date: d,
                                   pet: pet,
                                   name: base, // temporal
                                   dosage: med.dosage,
                                   frequency: med.frequency,
                                   notes: med.notes,
                                   prescriptionImageData: med.prescriptionImageData)
                context.insert(m)
                inserted.append(m)
                scheduleNotification(for: m)
            }
        }
        if inserted.isEmpty {
            infoText = "Todas las fechas calculadas ya existían."
            return
        }
        
        siblings.append(contentsOf: inserted)
        relabelSeries(base: base, siblings: siblings)
        
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        infoText = "Se añadieron \(inserted.count) dosis."
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: – UI subcomponentes locales
    private struct IntervalRow: View {
        @Binding var value: Int
        @Binding var unit: IntervalUnit
        var body: some View {
            HStack(spacing: 12) {
                Text("Cada")
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.body.monospacedDigit())
                
                Picker(selection: $unit) {
                    ForEach(IntervalUnit.allCases) { option in
                        Text(option.label).tag(option)
                    }
                } label: {
                    Text(unit.label)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minWidth: 80)
                
                Spacer()
                
                Stepper("", value: $value, in: 1...30)
                    .labelsHidden()
            }
        }
    }
    
    private struct MedicationPreviewView: View {
        let dates: [Date]
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Previsualización").font(.headline)
                ForEach(Array(dates.enumerated()), id: \.offset) { idx, d in
                    HStack {
                        Text("Dosis \(idx + 1)")
                        Spacer()
                        Text(d.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                }
            }
        }
    }
}

private struct VaccineDetailView: View {
    @Bindable var vac: Vaccine
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: vac.pet, title: vac.vaccineName, icon: "syringe", isCompleted: vac.isCompleted, date: vac.date)
            
            Section("Información") {
                TextField("Nombre", text: $vac.vaccineName)
                    .onChange(of: vac.vaccineName) { _, _ in save() }
                TextField("Fabricante", text: Binding($vac.manufacturer, replacingNilWith: ""))
                    .onChange(of: vac.manufacturer) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $vac.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: vac.date) { _, _ in reschedule(for: vac) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($vac.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: vac.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $vac.prescriptionImageData) {
                let newData = vac.prescriptionImageData
                propagatePrescriptionForVaccine(vac, with: newData, in: context)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
    
    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct DewormingDetailView: View {
    @Bindable var dew: Deworming
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: dew.pet, title: dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación", icon: "ladybug.fill", isCompleted: dew.isCompleted, date: dew.date)
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $dew.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: dew.date) { _, _ in reschedule(for: dew) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($dew.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: dew.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $dew.prescriptionImageData) {
                let newData = dew.prescriptionImageData
                propagatePrescriptionForDeworming(dew, with: newData, in: context)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
    
    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct GroomingDetailView: View {
    @Bindable var groom: Grooming
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        Form {
            Header(pet: groom.pet,
                   title: groom.displayName,
                   icon: "scissors",
                   isCompleted: groom.isCompleted,
                   date: groom.date)
            
            // Selección de servicios
            Section("Servicios") {
                ForEach(GroomingService.allCases) { service in
                    Toggle(service.displayName, isOn: Binding(
                        get: { groom.services.contains(service) },
                        set: { isOn in
                            if isOn {
                                if !groom.services.contains(service) {
                                    groom.services.append(service)
                                }
                            } else {
                                groom.services.removeAll { $0 == service }
                            }
                            save()
                        }
                    ))
                }
            }
            
            // Lugar y precio
            Section("Información") {
                TextField("Lugar", text: Binding($groom.location, replacingNilWith: ""))
                    .onChange(of: groom.location) { _, _ in save() }
                
                TextField("Precio total", value: Binding($groom.totalPrice, replacingNilWith: 0),
                          format: .currency(code: currencyCode))
                    .keyboardType(.decimalPad)
                    .onChange(of: groom.totalPrice) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $groom.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: groom.date) { _, _ in reschedule(for: groom) }
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
    
    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct WeightEntryDetailView: View {
    @Bindable var weight: WeightEntry
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: weight.pet, title: String(format: "Peso: %.1f kg", weight.weightKg), icon: "scalemass", isCompleted: true, date: weight.date)
            
            Section("Medición") {
                TextField("Peso (kg)", value: $weight.weightKg, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .onChange(of: weight.weightKg) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Tomado el",
                           selection: $weight.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: weight.date) { _, _ in reschedule(for: weight) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($weight.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: weight.notes) { _, _ in save() }
            }
            
            Section {
                Button("Eliminar registro", role: .destructive, action: onDelete)
            }
        }
    }
    
    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

// MARK: - Sección reutilizable de Prescripción

private struct PrescriptionSection: View {
    @Binding var imageData: Data?
    var onChange: () -> Void = {}
    
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingFullImage = false
    
    var body: some View {
        Section("Prescripción") {
            if let data = imageData, let ui = UIImage(data: data) {
                VStack(spacing: 8) {
                    Button {
                        showingFullImage = true
                    } label: {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                    HStack {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Reemplazar", systemImage: "photo")
                        }
                        
                        Button(role: .destructive) {
                            imageData = nil
                            onChange()
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        
                        Spacer()
                        
                        if let dataToShare = imageData {
                            ShareLink(item: dataToShare, preview: .init("Prescripción", image: Image(uiImage: ui)))
                        }
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                HStack {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                    
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Elegir de la fototeca", systemImage: "photo.on.rectangle")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.imageData = data
                        self.onChange()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(imageData: $imageData) {
                onChange()
            }
        }
        .fullScreenCover(isPresented: $showingFullImage) {
            if let data = imageData, let ui = UIImage(data: data) {
                ZoomableImageView(image: ui) {
                    showingFullImage = false
                }
            }
        }
    }
}

// MARK: - Pequeños helpers UI

private struct Header: View {
    let pet: Pet?
    let title: String
    let icon: String
    let isCompleted: Bool
    let date: Date
    
    var body: some View {
        HStack(spacing: 12) {
            if let data = pet?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "pawprint"))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(isCompleted ? "Completado" : "Pendiente")
                        .foregroundStyle(isCompleted ? .green : .orange)
                    Text(date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pet {
                    Text("🐾 \(pet.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Binding helpers para opcionales
private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith placeholder: String) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue }
        )
    }
}

private extension Binding where Value == Double {
    init(_ source: Binding<Double?>, replacingNilWith placeholder: Double) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

// MARK: - Viewer con zoom para la imagen de prescripción
private struct ZoomableImageView: View {
    let image: UIImage
    var onClose: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture().onChanged { value in
                        scale = max(1.0, value)
                    })
                    .gesture(DragGesture().onChanged { value in
                        offset = value.translation
                    }.onEnded { _ in
                        if scale == 1 { offset = .zero }
                    })
                    .background(Color.black.opacity(0.98))
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }
}

// MARK: - Propagación a toda la serie

private func propagatePrescriptionForMedication(_ med: Medication, with data: Data?, in context: ModelContext) {
    guard let petID = med.pet?.id else { return }
    let base = DoseSeries.splitDoseBase(from: med.name)
    let predicate = #Predicate<Medication> { m in
        m.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
    let siblings = fetched.filter { DoseSeries.splitDoseBase(from: $0.name) == base }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

private func propagatePrescriptionForVaccine(_ vac: Vaccine, with data: Data?, in context: ModelContext) {
    guard let petID = vac.pet?.id else { return }
    let base = DoseSeries.splitDoseBase(from: vac.vaccineName)
    let predicate = #Predicate<Vaccine> { v in
        v.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: predicate))) ?? []
    let siblings = fetched.filter { DoseSeries.splitDoseBase(from: $0.vaccineName) == base }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

private func propagatePrescriptionForDeworming(_ dew: Deworming, with data: Data?, in context: ModelContext) {
    guard let petID = dew.pet?.id else { return }
    let baseNotes = DoseSeries.normalizeNotes(dew.notes)
    let predicate = #Predicate<Deworming> { d in
        d.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))) ?? []
    let siblings = fetched.filter { DoseSeries.normalizeNotes($0.notes) == baseNotes }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

// MARK: - Previews (se mantienen igual que antes)

private enum EventDetailPreviewData {
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
}

#Preview("Detalle – Medicamento") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let med = Medication(date: Date().addingTimeInterval(3600),
                         pet: pet,
                         name: "Amoxicilina",
                         dosage: "250 mg",
                         frequency: "",
                         notes: "Tomar con comida")
    ctx.insert(med)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: med)
    }
    .modelContainer(container)
}

#Preview("Detalle – Vacuna") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    
    let vac = Vaccine(date: Date().addingTimeInterval(24*3600),
                      pet: pet,
                      vaccineName: "Rabia (dosis 1/3)",
                      manufacturer: "VetLabs",
                      notes: "Primera dosis")
    ctx.insert(vac)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: vac)
    }
    .modelContainer(container)
}

#Preview("Detalle – Desparasitación") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let dew = Deworming(date: Date().addingTimeInterval(7*24*3600),
                        pet: pet,
                        notes: "Tableta mensual")
    ctx.insert(dew)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: dew)
    }
    .modelContainer(container)
}

#Preview("Detalle – Grooming") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    
    let groom = Grooming(date: Date().addingTimeInterval(3*24*3600),
                         pet: pet,
                         location: "Pet Spa",
                         notes: "Baño y corte",
                         services: [.bano, .cortePelo, .corteUnas],
                         totalPrice: 550.0)
    ctx.insert(groom)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: groom)
    }
    .modelContainer(container)
}

#Preview("Detalle – Peso") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let weight = WeightEntry(date: Date().addingTimeInterval(-2*24*3600),
                             pet: pet,
                             weightKg: 23.4,
                             notes: "Post entrenamiento")
    ctx.insert(weight)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: weight)
    }
    .modelContainer(container)
}


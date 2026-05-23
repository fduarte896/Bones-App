//
//  EventQuickAddSheet.swift
//  Bones

import SwiftUI
import SwiftData
import UIKit

// MARK: - Tipos de evento
enum EventKind: String, CaseIterable, Identifiable {
    case deworming = "Desparasitación"
    case vaccine   = "Vacuna"
    case weight    = "Peso"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .deworming: "ladybug.fill"
        case .vaccine:   "syringe"
        case .weight:    "scalemass"
        }
    }
}

// MARK: - Previsualización de vacunas - Modelo visible a nivel de archivo
struct VaccinePreview {
    let seriesDates: [Date]
    let boosterRounds: [[Date]]
}

// MARK: - Hoja Quick-Add
struct EventQuickAddSheet: View {
    // Dependencias
    let pet: Pet
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // Guardamos los parámetros para sincronización defensiva
    private let initialKindParam: EventKind
    
    // Init
    init(pet: Pet, initialKind: EventKind = .vaccine) {
        self.pet = pet
        self.initialKindParam = initialKind
        _kind = State(initialValue: initialKind)
        print("[QuickAddSheet.init] initialKind=\(initialKind)")
    }
    
    // ----------------- Estado -----------------
    @State private var kind: EventKind
    
    // Comunes
    @State private var title = ""
    @State private var eventDate = Date().addingTimeInterval(60*60)
    
    // Desparasitación – RRULE
    @State private var rruleEnabled = false
    @State private var rruleIntervalValue = 3
    @State private var rruleIntervalUnit: IntervalUnit = .months
    
    // Vacuna
    @State private var manufacturer = ""
    
    // Peso
    enum WeightUnit: String, CaseIterable, Identifiable { case kg = "kg", lb = "lb"; var id: Self { self } }
    @State private var weightText = ""
    @State private var weightUnit: WeightUnit = .kg
    @State private var weightNotes = ""
    
    // Mostrar botón "Ahora" solo si el usuario cambió la fecha en Peso
    @State private var weightDateDirty = false
    @State private var isSettingEventDateProgrammatically = false
    
    // Programación futura
    @State private var scheduleEnabled = false
    
    // — Vacunas —
    // Modo
    enum VaccineSchedulingMode: String, CaseIterable, Identifiable {
        case automatic = "Automático"
        case manual = "Manual"
        var id: Self { self }
    }
    @State private var vaccineMode: VaccineSchedulingMode = .automatic
    
    // Serie actual (automático)
    // IMPORTANTE: este valor representa "dosis extra" (adicionales a la inicial)
    @State private var vaccineSeriesDoseCount: Int = 2
    @State private var vaccineSeriesSpacingValue: Int = 1
    @State private var vaccineSeriesSpacingUnit: IntervalUnit = .weeks
    
    // Refuerzos (automático)
    @State private var boostersEnabled: Bool = true
    @State private var boosterFrequencyValue: Int = 12
    @State private var boosterFrequencyUnit: IntervalUnit = .months // 12 meses = anual
    @State private var boosterRoundsCount: Int = 1
    @State private var boosterIncludesSeries: Bool = false
    
    // Manual (fechas adicionales)
    @State private var vaccineDoses: [VaccineDose] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // ---------- Tipo (Picker tradicional) ----------
                Section("Tipo") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(EventKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.icon).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // ---------- Detalles ----------
                Section("Detalles") { detailsSection }
                
                // ---------- Fecha ----------
                Section("Fecha") {
                    let dateLabel: String = {
                        switch kind {
                        case .deworming, .vaccine: return "Primera dosis"
                        case .weight:              return "Fecha y hora"
                        }
                    }()
                    DatePicker(dateLabel,
                               selection: $eventDate,
                               displayedComponents: [.date, .hourAndMinute])
                    if kind == .weight && weightDateDirty {
                        Button("Ahora") {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            isSettingEventDateProgrammatically = true
                            eventDate = Date()
                            weightDateDirty = false
                            isSettingEventDateProgrammatically = false
                        }
                        .buttonStyle(.borderless)
                        .tint(.blue)
                    }
                }
                
                // ---------- Programación futura ----------
                futureScheduleSection
                
                // ---------- RRULE para desparasitación ----------
                if kind == .deworming {
                    Section("Recordatorio futuro") {
                        Toggle("Crear recordatorio para la próxima recurrencia", isOn: $rruleEnabled)
                        if rruleEnabled {
                            HStack {
                                Text("Cada")
                                    .foregroundStyle(.secondary)
                                Stepper(value: $rruleIntervalValue, in: 1...30) {
                                    Text("\(rruleIntervalValue)")
                                        .font(.body.monospacedDigit())
                                }
                                Picker("", selection: $rruleIntervalUnit) {
                                    Text(IntervalUnit.days.label).tag(IntervalUnit.days)
                                    Text(IntervalUnit.weeks.label).tag(IntervalUnit.weeks)
                                    Text(IntervalUnit.months.label).tag(IntervalUnit.months)
                                }
                                .pickerStyle(.menu)
                            }

                            Text("Nota: Se creará un único recordatorio futuro. Cuando llegue, podrás ajustar y programar la nueva serie.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // ---------- Validación Peso ----------
                if kind == .weight, let warning = validationMessageWeight() {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Nuevo evento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveEvent() }
                        .disabled(saveDisabled)
                }
            }
            .onAppear {
                // Sincronización defensiva del estado con los parámetros recibidos
                if kind != initialKindParam {
                    print("[QuickAddSheet.onAppear] Resync kind \(kind) → \(initialKindParam)")
                    kind = initialKindParam
                }
                if kind == .weight { prefillWeight() }
                print("[QuickAddSheet.onAppear] kind=\(kind)")
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .weight { prefillWeight() }
            }
            .onChange(of: eventDate) { _, _ in
                if kind == .weight && !isSettingEventDateProgrammatically {
                    weightDateDirty = true
                }
            }
        }
    }
    
    private var saveDisabled: Bool {
        if kind == .weight {
            return !canSaveWeight()
        } else {
            return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Sub-vistas UI
private extension EventQuickAddSheet {
    
    @ViewBuilder var detailsSection: some View {
        switch kind {
        case .deworming:
            TextField("Nombre del desparasitante", text: $title)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            
        case .vaccine:
            TextField("Nombre de la vacuna", text: $title)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            TextField("Fabricante", text: $manufacturer)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
        case .weight:
            VStack(alignment: .leading, spacing: 8) {
                // Medición
                HStack {
                    TextField("Peso", text: $weightText)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    Picker("", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 120)
                }
                
                HStack {
                    Button {
                        adjustWeight(-0.1)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Button {
                        adjustWeight(+0.1)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
                
                // Notas
                TextField("Notas (opcional)", text: $weightNotes, axis: .vertical)
                    .lineLimit(1...4)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }
    
    @ViewBuilder var futureScheduleSection: some View {
        if kind == .vaccine {
            Section {
                Toggle("Programar próximas dosis", isOn: $scheduleEnabled)
                
                if scheduleEnabled {
                    vaccineControls
                }
            }
        }
    }
    
    // ---- Vacunas ----
    struct VaccineDose: Identifiable, Equatable {
        let id = UUID()
        var date: Date
    }
    
    @ViewBuilder var vaccineControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Selector de modo
            Picker("Modo", selection: $vaccineMode) {
                ForEach(VaccineSchedulingMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }.pickerStyle(.segmented)
            
            if vaccineMode == .automatic {
                // Serie actual
                Group {
                    Text("Serie actual").font(.headline)
                    // Este valor es "extra", por eso el texto
                    Stepper("Número de dosis extra: \(vaccineSeriesDoseCount)", value: $vaccineSeriesDoseCount, in: 1...5)
                    HStack {
                        Spacer()
                        IntervalRow(value: $vaccineSeriesSpacingValue, unit: $vaccineSeriesSpacingUnit)
                    }
                }
                
                // Refuerzos
                Group {
                    Toggle("Programar refuerzos", isOn: $boostersEnabled)
                    if boostersEnabled {
                        HStack {
                            Spacer()
                            IntervalRow(value: $boosterFrequencyValue, unit: $boosterFrequencyUnit)
                        }
                        Stepper("Cantidad de rondas: \(boosterRoundsCount)", value: $boosterRoundsCount, in: 1...5)
                        Toggle("Incluir serie corta en refuerzo", isOn: $boosterIncludesSeries)
                    }
                }
                
                // Previsualización
                if let preview = vaccinePreview(
                    start: eventDate,
                    seriesCount: vaccineSeriesDoseCount, // extra
                    seriesSpacingValue: vaccineSeriesSpacingValue,
                    seriesSpacingUnit: vaccineSeriesSpacingUnit,
                    boostersEnabled: boostersEnabled,
                    boosterFreqValue: boosterFrequencyValue,
                    boosterFreqUnit: boosterFrequencyUnit,
                    boosterRounds: boosterRoundsCount,
                    boosterIncludesSeries: boosterIncludesSeries
                ) {
                    VaccinePreviewView(preview: preview)
                }
                
            } else {
                // Modo manual (tu UI actual)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array($vaccineDoses.enumerated()), id: \.element.id) { idx, $dose in
                        DatePicker("Dosis \(idx + 2)",
                                   selection: $dose.date,
                                   displayedComponents: .date)
                    }
                    
                    HStack {
                        Button {
                            let base = vaccineDoses.last?.date ?? eventDate
                            let next = Calendar.current.date(byAdding: .month, value: 1, to: base)!
                            vaccineDoses.append(VaccineDose(date: next))
                        } label: { Label("Añadir dosis", systemImage: "plus.circle") }
                        .disabled(vaccineDoses.count >= 5)
                        
                        if !vaccineDoses.isEmpty {
                            Spacer()
                            Button("Limpiar", role: .destructive) { vaccineDoses.removeAll() }
                        }
                    }
                }
            }
        }
    }
    
    private func index(of id: UUID) -> Int {
        vaccineDoses.firstIndex { $0.id == id } ?? 0
    }
    
    
    
    struct IntervalRow: View {
        @Binding var value: Int
        @Binding var unit: IntervalUnit
        var allowedUnits: [IntervalUnit] = IntervalUnit.allCases
        var body: some View {
            HStack(spacing: 12) {
                Text("Cada")
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.body.monospacedDigit())
                
                // Unidad pegada al número
                if allowedUnits.count == 1, let only = allowedUnits.first {
                    Text(only.label)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(selection: $unit) {
                        ForEach(allowedUnits) { option in
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
                }
                
                Spacer()
                
                Stepper("", value: $value, in: 1...30)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Previsualización de vacunas
private struct VaccinePreviewView: View {
    let preview: VaccinePreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Previsualización").font(.headline)
            // Serie actual
            if !preview.seriesDates.isEmpty {
                Text("Serie actual:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Array(preview.seriesDates.enumerated()), id: \.offset) { idx, d in
                    HStack {
                        Text("Dosis \(idx + 1)")
                        Spacer()
                        Text(d, format: .dateTime.day().month().year())
                    }.font(.caption)
                }
            }
            // Refuerzos
            if !preview.boosterRounds.isEmpty {
                Text("Refuerzos:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(Array(preview.boosterRounds.enumerated()), id: \.offset) { idx, round in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ronda \(idx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(round, id: \.self) { d in
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption2)
                                Spacer()
                                Text(d, format: .dateTime.day().month().year())
                            }
                            .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Guardado
extension EventQuickAddSheet {
    
    private func saveEvent() {
        if kind == .weight {
            // Guardar peso
            guard let val = parseLocalizedDouble(weightText) else { return }
            let kg = weightUnit == .kg ? val : val * 0.45359237
            let w = WeightEntry(date: eventDate, pet: pet, weightKg: kg, notes: weightNotes.isEmpty ? nil : weightNotes)
            context.insert(w)
            try? context.save()
            NotificationCenter.default.post(name: .eventsDidChange, object: nil)
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            dismiss()
            return
        }
        
        if kind == .deworming {
            // Guardar desparasitación
            let dewormSeriesID = UUID()
            let rrule: String? = rruleEnabled ? makeRRULE(value: rruleIntervalValue, unit: rruleIntervalUnit) : nil
            let notes = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let d = Deworming(date: eventDate, pet: pet, notes: notes.isEmpty ? nil : notes, prescriptionImageData: nil, seriesID: dewormSeriesID)
            d.rrule = rrule
            d.isRecurring = (rrule != nil)
            context.insert(d)
            notify(id: d.id, title: "Desparasitación", body: "\(pet.name) – \(notes.isEmpty ? "Desparasitación" : notes)", at: eventDate)
            
            // Expansión de RRULE: crea el siguiente recordatorio futuro
            if let rrule {
                expandDewormingRecurrence(anchor: eventDate, seriesID: dewormSeriesID, rrule: rrule)
            }
            
            try? context.save()
            NotificationCenter.default.post(name: .eventsDidChange, object: nil)
            dismiss()
            return
        }
        
        // Vacuna
        let primary = insertVaccineEvent(on: eventDate, doseLabel: nil)
        if scheduleEnabled { scheduleFutureVaccines(from: primary) }
        
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        dismiss()
    }
    
    @discardableResult
    private func insertVaccineEvent(on date: Date, doseLabel: String?) -> Vaccine {
        let name = doseLabel.map { "\(title) (\($0))" } ?? title
        let v = Vaccine(date: date, pet: pet,
                        vaccineName: name, manufacturer: manufacturer)
        context.insert(v)
        notify(id: v.id, title: "Vacuna",
               body: "\(pet.name) – \(title)", at: date)
        return v
    }
    
    private func scheduleFutureVaccines(from primary: Vaccine) {
        if vaccineMode == .automatic {
            // Serie actual
            // vaccineSeriesDoseCount es "extra", por eso sumamos 1 para incluir la inicial
            let seriesDates = generateSeries(
                start: primary.date,
                count: vaccineSeriesDoseCount + 1,
                spacingValue: vaccineSeriesSpacingValue,
                spacingUnit: vaccineSeriesSpacingUnit
            )
            let total = seriesDates.count
            // Omitimos la primera (primary) para mantener consistencia
            var idx = 2
            for d in seriesDates.dropFirst() {
                insertVaccineEvent(on: d, doseLabel: "dosis \(idx)/\(total)")
                idx += 1
            }
            // Refuerzos
            if boostersEnabled {
                let boosterStarts = generateBoosterStarts(
                    start: primary.date,
                    rounds: boosterRoundsCount,
                    freqValue: boosterFrequencyValue,
                    freqUnit: boosterFrequencyUnit
                )
                for start in boosterStarts {
                    if boosterIncludesSeries {
                        let round = generateSeries(
                            start: start,
                            count: vaccineSeriesDoseCount + 1,
                            spacingValue: vaccineSeriesSpacingValue,
                            spacingUnit: vaccineSeriesSpacingUnit
                        )
                        let rTotal = round.count
                        var rIdx = 2
                        for d in round.dropFirst() {
                            insertVaccineEvent(on: d, doseLabel: "dosis \(rIdx)/\(rTotal)")
                            rIdx += 1
                        }
                    } else {
                        insertVaccineEvent(on: start, doseLabel: nil)
                    }
                }
            }
        } else {
            // Modo manual: usar fechas provistas
            for dose in vaccineDoses.sorted(by: { $0.date < $1.date }) {
                insertVaccineEvent(on: dose.date, doseLabel: nil)
            }
        }
    }
    
    private func notify(id: UUID, title: String, body: String, at date: Date) {
        NotificationManager.shared.scheduleNotification(
            id: id, title: title, body: body, fireDate: date, advance: 0)
    }
}

// MARK: - Helpers de cálculo, RRULE y validación
private extension EventQuickAddSheet {
    func prefillWeight() {
        // Prefill con último peso de la mascota (igual que en la tab)
        let petID = pet.id
        let predicate = #Predicate<WeightEntry> { $0.pet?.id == petID }
        var desc = FetchDescriptor<WeightEntry>(predicate: predicate)
        desc.sortBy = [SortDescriptor(\.date, order: .reverse)]
        let last = (try? context.fetch(desc))?.first
        if let w = last?.weightKg {
            let value = weightUnit == .kg ? w : (w / 0.45359237)
            weightText = String(format: "%.1f", value)
        } else {
            weightText = ""
        }
        isSettingEventDateProgrammatically = true
        eventDate = Date()
        weightDateDirty = false
        isSettingEventDateProgrammatically = false
        weightNotes = ""
    }
    
    func adjustWeight(_ delta: Double) {
        let current = parseLocalizedDouble(weightText) ?? 0
        let newVal = max(0, (current + delta)).rounded(toPlaces: 1)
        weightText = String(format: "%.1f", newVal)
    }
    
    func speciesRange() -> (min: Double, max: Double) {
        switch pet.species {
        case .perro: return (0.5, 120.0)
        case .gato:  return (0.5, 15.0)
        }
    }
    
    func canSaveWeight() -> Bool {
        guard let val = parseLocalizedDouble(weightText), val > 0 else { return false }
        let (minV, maxV) = speciesRange()
        let kg = weightUnit == .kg ? val : val * 0.45359237
        return kg >= minV && kg <= maxV
    }
    
    func validationMessageWeight() -> String? {
        guard let val = parseLocalizedDouble(weightText), val > 0 else {
            return "Introduce un peso válido mayor que 0."
        }
        let (minV, maxV) = speciesRange()
        let kg = weightUnit == .kg ? val : val * 0.45359237
        if kg < minV || kg > maxV {
            return "Valor fuera de rango para \(pet.species == .perro ? "perro" : "gato"): \(String(format: "%.1f", minV))–\(String(format: "%.1f", maxV)) kg."
        }
        return nil
    }
    
    func parseLocalizedDouble(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        if let n = nf.number(from: trimmed) {
            return n.doubleValue
        }
        let dot = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(dot)
    }
    
    // MARK: - Generadores de fechas y previsualizaciones
    
    // Agrega un intervalo a una fecha según la unidad
    func addInterval(_ value: Int, unit: IntervalUnit, to date: Date) -> Date {
        let cal = Calendar.current
        switch unit {
        case .hours:  return cal.date(byAdding: .hour, value: value, to: date) ?? date
        case .days:   return cal.date(byAdding: .day, value: value, to: date) ?? date
        case .weeks:  return cal.date(byAdding: .weekOfYear, value: value, to: date) ?? date
        case .months: return cal.date(byAdding: .month, value: value, to: date) ?? date
        }
    }
    
    // Serie de vacunas (incluye la fecha inicial). 'count' mínimo 1.
    func generateSeries(start: Date,
                        count: Int,
                        spacingValue: Int,
                        spacingUnit: IntervalUnit) -> [Date] {
        let c = max(1, count)
        var dates: [Date] = [start]
        var current = start
        if c > 1 {
            for _ in 1..<c {
                current = addInterval(spacingValue, unit: spacingUnit, to: current)
                dates.append(current)
            }
        }
        return dates
    }
    
    // Fechas de inicio de refuerzos (solo las fechas de arranque de cada ronda)
    func generateBoosterStarts(start: Date,
                               rounds: Int,
                               freqValue: Int,
                               freqUnit: IntervalUnit) -> [Date] {
        guard rounds > 0 else { return [] }
        var starts: [Date] = []
        var current = start
        for _ in 0..<rounds {
            current = addInterval(freqValue, unit: freqUnit, to: current)
            starts.append(current)
        }
        return starts
    }
    
    // Previsualización de vacunas (serie + refuerzos)
    func vaccinePreview(start: Date,
                        seriesCount: Int,
                        seriesSpacingValue: Int,
                        seriesSpacingUnit: IntervalUnit,
                        boostersEnabled: Bool,
                        boosterFreqValue: Int,
                        boosterFreqUnit: IntervalUnit,
                        boosterRounds: Int,
                        boosterIncludesSeries: Bool) -> VaccinePreview? {
        // Serie actual: seriesCount es "extra", por eso sumamos 1 para incluir la inicial
        let series = generateSeries(start: start,
                                    count: max(1, seriesCount + 1),
                                    spacingValue: seriesSpacingValue,
                                    spacingUnit: seriesSpacingUnit)
        
        var rounds: [[Date]] = []
        if boostersEnabled {
            let starts = generateBoosterStarts(start: start,
                                               rounds: boosterRounds,
                                               freqValue: boosterFrequencyValue,
                                               freqUnit: boosterFrequencyUnit)
            for s in starts {
                if boosterIncludesSeries {
                    let r = generateSeries(start: s,
                                           count: max(1, seriesCount + 1),
                                           spacingValue: seriesSpacingValue,
                                           spacingUnit: seriesSpacingUnit)
                    rounds.append(r)
                } else {
                    rounds.append([s])
                }
            }
        }
        
        return VaccinePreview(seriesDates: series, boosterRounds: rounds)
    }
    
    // MARK: - RRULE helpers
    func makeRRULE(value: Int, unit: IntervalUnit) -> String {
        let freq: String
        switch unit {
        case .hours:  freq = "HOURLY"
        case .days:   freq = "DAILY"
        case .weeks:  freq = "WEEKLY"
        case .months: freq = "MONTHLY"
        }
        let interval = max(1, value)
        return "FREQ=\(freq);INTERVAL=\(interval)"
    }
    
    // MARK: - RRULE simple (Desparasitación)
    func expandDewormingRecurrence(anchor: Date, seriesID: UUID, rrule: String) {
        // Parse básico de "FREQ=...;INTERVAL=N"
        let parts = rrule
            .split(separator: ";")
            .reduce(into: [String:String]()) { dict, kv in
                let p = kv.split(separator: "=", maxSplits: 1).map(String.init)
                if p.count == 2 { dict[p[0].uppercased()] = p[1].uppercased() }
            }
        guard let freq = parts["FREQ"] else { return }
        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        
        // Decide la unidad
        let unit: IntervalUnit
        switch freq {
        case "HOURLY":  unit = .hours
        case "DAILY":   unit = .days
        case "WEEKLY":  unit = .weeks
        case "MONTHLY": unit = .months
        default:        unit = .months
        }
        
        // Solo crea el siguiente recordatorio
        let next = addInterval(interval, unit: unit, to: anchor)
        if !existsDeworming(seriesID: seriesID, date: next, petID: pet.id) {
            let notes = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let d = Deworming(date: next, pet: pet, notes: notes.isEmpty ? nil : notes, prescriptionImageData: nil, seriesID: seriesID)
            d.rrule = rrule
            d.isRecurring = true
            context.insert(d)
            notify(id: d.id, title: "Desparasitación",
                   body: "\(pet.name) – \(notes.isEmpty ? "Desparasitación" : notes)", at: next)
        }
    }
    
    func existsDeworming(seriesID: UUID, date: Date, petID: UUID) -> Bool {
        let predicate = #Predicate<Deworming> { dew in
            dew.pet?.id == petID && dew.seriesID == seriesID && dew.date == date
        }
        let fetched = try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))
        return (fetched?.isEmpty == false)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

#Preview {
    NavigationStack {
        EventQuickAddSheet(pet: Pet(name: "Firulais"), initialKind: .vaccine)
            .modelContainer(for: Pet.self, inMemory: true)
    }
}

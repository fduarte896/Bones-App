//
//  EventQuickAddSheet.swift
//  Bones
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Tipos de evento
enum EventKind: String, CaseIterable, Identifiable {
    case medication  = "Medicamento"
    case vaccine     = "Vacuna"
    case grooming    = "Grooming"
    case weight      = "Peso"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .medication: "pills.fill"
        case .vaccine:    "syringe"
        case .grooming:   "scissors"
        case .weight:     "scalemass"
        }
    }
}

// MARK: - Intervalo y programaciones
enum IntervalUnit: String, CaseIterable, Identifiable {
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
enum ScheduleMode: String, CaseIterable, Identifiable {
    case interval, perDay
    var id: Self { self }
    var label: String { self == .interval ? "Dosis por horas" : "Dosis por día" }
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
    private let initialIsDewormingParam: Bool
    
    // Init
    init(pet: Pet, initialKind: EventKind = .medication, isDewormingInitial: Bool = false) {
        self.pet = pet
        self.initialKindParam = initialKind
        self.initialIsDewormingParam = (initialKind == .medication) ? isDewormingInitial : false
        
        _kind = State(initialValue: initialKind)
        _isDeworming = State(initialValue: (initialKind == .medication) ? isDewormingInitial : false)
        
        // DEBUG
        print("[QuickAddSheet.init] initialKind=\(initialKind) isDew=\(isDewormingInitial)")
    }
    
    // ----------------- Estado -----------------
    @State private var kind: EventKind
    
    // NUEVO: Quick Add por texto (IA)
    @State private var quickAddText: String = ""
    @State private var quickAddInfo: String?
    @State private var quickAddWarning: String?
    @State private var lastParsed: ProposedEvent?
    @State private var isAnalyzing = false
    @State private var isSuggesting = false
    
    // Comunes
    @State private var title = ""
    @State private var eventDate = Date().addingTimeInterval(60*60)
    
    // Medicamento
    @State private var dosage = ""
    @State private var frequency = ""
    // NUEVO: marcar como desparasitante
    @State private var isDeworming = false
    
    // NUEVO: RRULE para desparasitación
    @State private var rruleEnabled = false
    @State private var rruleIntervalValue = 3
    @State private var rruleIntervalUnit: IntervalUnit = .months
    
    // Vacuna
    @State private var manufacturer = ""
    
    // Grooming
    @State private var location = ""
    @State private var selectedServices: Set<GroomingService> = []
    @State private var priceText: String = ""
    
    // Peso
    enum WeightUnit: String, CaseIterable, Identifiable { case kg = "kg", lb = "lb"; var id: Self { self } }
    @State private var weightText = ""
    @State private var weightUnit: WeightUnit = .kg
    @State private var weightNotes = ""
    
    // Mostrar botón “Ahora” solo si el usuario cambió la fecha en Peso
    @State private var weightDateDirty = false
    @State private var isSettingEventDateProgrammatically = false
    
    // Programación futura
    @State private var scheduleEnabled = false
    
    // — Medicamentos —
    @State private var scheduleMode: ScheduleMode = .interval
    @State private var intervalValue = 8
    @State private var intervalUnit: IntervalUnit = .hours
    // compat: no usado en .interval
    @State private var repeatCount = 1
    
    @State private var timesPerDay = 3
    @State private var durationDays = 5   // también usado en .interval
    
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
    
    // Moneda local (para mostrar en el campo de precio)
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // ---------- Quick Add por texto (IA) ----------
                #if !TESTFLIGHT
                Section("Añadir por texto") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Ej.: Amoxicilina 250 mg cada 8 h mañana 6pm",
                                  text: $quickAddText, axis: .vertical)
                            .lineLimit(1...3)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(true)
                        
                        HStack {
                            Button {
                                Task {
                                    await analyzeQuickAdd()
                                }
                            } label: {
                                Label(isAnalyzing ? "Analizando…" : "Analizar", systemImage: isAnalyzing ? "hourglass" : "wand.and.stars")
                            }
                            .disabled(isAnalyzing || quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Button {
                                Task {
                                    await suggestSeries()
                                }
                            } label: {
                                Label(isSuggesting ? "Sugerir…" : "Sugerir serie", systemImage: "calendar.badge.plus")
                            }
                            .disabled(isSuggesting || !canSuggestSeries)
                            
                            if let info = quickAddInfo, !info.isEmpty {
                                Spacer()
                                Text(info)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        if let warn = quickAddWarning {
                            Label(warn, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.footnote)
                        }
                    }
                }
                #endif
                
                // ---------- Tipo (Picker tradicional) ----------
                Section("Tipo") {
                    Picker("Tipo", selection: $kind) {
                        ForEach(EventKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.icon).tag(k)
                        }
                    }
                    .pickerStyle(.menu) // ← Popup/menú emergente anclado al row

                }
                
                // ---------- Detalles ----------
                Section("Detalles") { detailsSection }
                
                // ---------- Fecha ----------
                Section("Fecha") {
                    let dateLabel: String = {
                        switch kind {
                        case .medication, .vaccine: return "Primera dosis"
                        case .grooming, .weight:    return "Fecha y hora"
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
                if kind == .medication && isDeworming {
                    Section("Recurrencias") {
                        Toggle("Crear recurrencias", isOn: $rruleEnabled)
                        if rruleEnabled {
                            HStack {
                                Text("Cada")
                                    .foregroundStyle(.secondary)
                                Stepper(value: $rruleIntervalValue, in: 1...30) {
                                    Text("\(rruleIntervalValue)")
                                        .font(.body.monospacedDigit())
                                }
                                Picker("", selection: $rruleIntervalUnit) {
                                    // Horas también soportado por RRULE, pero normalmente no se usa en desparasitación.
                                    Text(IntervalUnit.days.label).tag(IntervalUnit.days)
                                    Text(IntervalUnit.weeks.label).tag(IntervalUnit.weeks)
                                    Text(IntervalUnit.months.label).tag(IntervalUnit.months)
                                }
                                .pickerStyle(.menu)
                            }

                            Text("Nota: Las recurrencias crearán este mismo evento de acuerdo a tu frecuencia seleccionada.")
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
                if initialKindParam == .medication {
                    if isDeworming != initialIsDewormingParam {
                        print("[QuickAddSheet.onAppear] Resync isDeworming \(isDeworming) → \(initialIsDewormingParam)")
                        isDeworming = initialIsDewormingParam
                    }
                } else if isDeworming {
                    print("[QuickAddSheet.onAppear] Clear isDeworming because kind != .medication")
                    isDeworming = false
                }
                
                if kind == .weight { prefillWeight() }
                
                print("[QuickAddSheet.onAppear] kind=\(kind) isDew=\(isDeworming)")
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .weight { prefillWeight() }
                // Si cambiamos a otro tipo, limpiar flag de desparasitación salvo que sigamos en Medicamento
                if newKind != .medication && isDeworming {
                    isDeworming = false
                }
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
        } else if kind == .grooming {
            let descEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return descEmpty && selectedServices.isEmpty
        } else {
            return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Sub-vistas UI
private extension EventQuickAddSheet {
    
    @ViewBuilder var detailsSection: some View {
        switch kind {
        case .medication:
            TextField(isDeworming ? "Nombre del desparasitante" : "Nombre del medicamento", text: $title)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            
            // Toggle para tratar como Desparasitación (también visible en la sección Tipo)
            Toggle("Es un desparasitante?", isOn: $isDeworming)
            
            // Campo de dosis (activo incluso cuando es desparasitante; se guardará como nota informativa)
            TextField("Dosis (ej. 10 mg)", text: $dosage)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            
        case .vaccine:
            TextField("Nombre de la vacuna", text: $title)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            TextField("Fabricante", text: $manufacturer)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
        case .grooming:
            TextField("Descripción (opcional)", text: $title)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            TextField("Lugar (opcional)", text: $location)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
            
            // Precio (opcional)
            HStack {
                TextField("Precio (opcional)", text: $priceText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Text(currencyCode)
                    .foregroundStyle(.secondary)
            }
            
            // ---------- Servicios ----------
            VStack(alignment: .leading, spacing: 8) {
                Text("Servicios")
                    .font(.headline)
                ForEach(GroomingService.allCases) { service in
                    Toggle(service.displayName, isOn: binding(for: service))
                        .toggleStyle(.switch)
                }
                if !selectedServices.isEmpty {
                    Button("Limpiar selección", role: .destructive) {
                        selectedServices.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }
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
        if kind == .medication || kind == .vaccine {
            Section {
                Toggle("Programar próximas dosis", isOn: $scheduleEnabled)
                
                if scheduleEnabled {
                    if kind == .medication { medicationControls }
                    if kind == .vaccine   { vaccineControls }
                }
            }
        }
    }
    
    // ---- Medicamentos / Desparasitación ----
    var medicationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ModeChips
            if scheduleMode == .interval {
                IntervalRow(value: $intervalValue, unit: $intervalUnit)
                Stepper("Durante \(durationDays) día(s)", value: $durationDays, in: 1...90)
                
                // Resumen en vivo
                let summary = intervalSummary(
                    start: eventDate,
                    durationDays: durationDays,
                    stepValue: intervalValue,
                    stepUnit: intervalUnit
                )
                if let summary {
                    Text("Se crearán \(summary.total) dosis en total. Última: \(summary.last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Stepper("\(timesPerDay) × por día", value: $timesPerDay, in: 1...12)
                Stepper("Durante \(durationDays) día(s)", value: $durationDays, in: 1...30)
            }
            
            // Previsualización detallada (ambos modos)
            if let medDates = medicationPreview(
                start: eventDate,
                mode: scheduleMode,
                intervalValue: intervalValue,
                intervalUnit: intervalUnit,
                durationDays: durationDays,
                timesPerDay: timesPerDay
            ), medDates.count > 1 {
                MedicationPreviewView(dates: medDates)
                    .padding(.top, 4)
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
    
    // Chips de modo (medicamentos)
    var ModeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ScheduleMode.allCases) { m in
                    Button { scheduleMode = m } label: {
                        Text(m.label)
                            .font(.caption)
                            .padding(.vertical,5).padding(.horizontal,10)
                            .background(Capsule().fill(scheduleMode == m ? Color.accentColor
                                                                          : Color(.systemGray5)))
                            .foregroundStyle(scheduleMode == m ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }.padding(.horizontal,4)
        }
    }
    
    struct IntervalRow: View {
        @Binding var value: Int
        @Binding var unit: IntervalUnit
        var body: some View {
            HStack(spacing: 12) {
                Text("Cada")
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.body.monospacedDigit())
                
                // Unidad pegada al número
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

// MARK: - Previsualización de medicamentos
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

// MARK: - Guardado
extension EventQuickAddSheet {
    
    private func saveEvent() {
        if kind == .weight {
            // Guardar peso (idéntico a la pestaña Peso)
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
        
        // Si es desparasitante, generamos una serieID única para agrupar
        let dewormSeriesID: UUID? = (kind == .medication && isDeworming) ? UUID() : nil
        let rrule: String? = (kind == .medication && isDeworming && rruleEnabled) ? makeRRULE(value: rruleIntervalValue, unit: rruleIntervalUnit) : nil
        
        // Inserta el evento principal
        let primary = insertEvent(on: eventDate, doseLabel: nil, dewormSeriesID: dewormSeriesID, rrule: rrule)
        
        // Programaciones futuras “manuales” (medicamentos/vacunas)
        if scheduleEnabled { scheduleFuture(from: primary, dewormSeriesID: dewormSeriesID, rrule: rrule) }
        
        // Expansión de RRULE para desparasitación (crea futuras ocurrencias reales)
        if kind == .medication, isDeworming, let rrule, let seriesID = dewormSeriesID {
            expandDewormingRecurrence(anchor: eventDate, seriesID: seriesID, rrule: rrule)
        }
        
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        dismiss()
    }
    
    @discardableResult
    private func insertEvent(on date: Date,
                             doseLabel: String?,
                             dewormSeriesID: UUID? = nil,
                             rrule: String? = nil) -> any BasicEvent {
        switch kind {
        case .medication:
            if isDeworming {
                // Notas = título [+ dosis informativa] [+ " (dosis X/Y)"]
                var base = title
                let trimmedDose = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedDose.isEmpty {
                    base += " – \(trimmedDose)"
                }
                let notes = doseLabel.map { "\(base) (\($0))" } ?? base
                let d = Deworming(date: date, pet: pet, notes: notes, prescriptionImageData: nil, seriesID: dewormSeriesID)
                d.rrule = rrule
                d.isRecurring = (rrule != nil)
                context.insert(d)
                notify(id: d.id, title: "Desparasitación",
                       body: "\(pet.name) – \(notes)", at: date)
                return d
            } else {
                let name = doseLabel.map { "\(title) (\($0))" } ?? title
                let m = Medication(date: date, pet: pet,
                                   name: name, dosage: dosage, frequency: frequency)
                context.insert(m)
                notify(id: m.id, title: "Medicamento",
                       body: "\(pet.name) – \(name)", at: date)
                return m
            }
        case .vaccine:
            // Etiquetamos dosis X/Y cuando corresponda
            let name = doseLabel.map { "\(title) (\($0))" } ?? title
            let v = Vaccine(date: date, pet: pet,
                            vaccineName: name, manufacturer: manufacturer)
            context.insert(v)
            notify(id: v.id, title: "Vacuna",
                   body: "\(pet.name) – \(title)", at: date)
            return v
        case .grooming:
            let notes = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title
            let loc = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location
            let services = Array(selectedServices)
            let price = parseLocalizedDouble(priceText)
            let g = Grooming(date: date, pet: pet,
                             location: loc, notes: notes, services: services, totalPrice: price)
            context.insert(g)
            // Notificación: prioriza servicios; si no hay, usa descripción
            let bodyText: String = {
                if !services.isEmpty {
                    return services.map { $0.displayName }.joined(separator: ", ")
                } else {
                    return notes ?? pet.name
                }
            }()
            notify(id: g.id, title: "Grooming",
                   body: "\(pet.name) – \(bodyText)", at: date)
            return g
        case .weight:
            // No se usa aquí; el guardado de peso se maneja arriba
            let g = Grooming(date: date, pet: pet, location: nil, notes: "")
            return g
        }
    }
    
    private func scheduleFuture(from primary: any BasicEvent, dewormSeriesID: UUID? = nil, rrule: String? = nil) {
        let cal = Calendar.current
        var next = primary.date
        var doseIndex = 1
        
        func add(_ val: Int, _ unit: IntervalUnit, to date: Date) -> Date {
            switch unit {
            case .hours:  cal.date(byAdding: .hour,  value: val, to: date)!
            case .days:   cal.date(byAdding: .day,   value: val, to: date)!
            case .weeks:  cal.date(byAdding: .day,   value: 7 * val, to: date)!
            case .months: cal.date(byAdding: .month, value: val, to: date)!
            }
        }
        
        switch kind {
        case .medication:
            if scheduleMode == .interval {
                // Generar todas las fechas hasta el fin (duración en días)
                let end = cal.date(byAdding: .day, value: durationDays, to: primary.date)!
                var dates: [Date] = []
                var current = primary.date
                while true {
                    let candidate = add(intervalValue, intervalUnit, to: current)
                    if candidate > end { break }
                    dates.append(candidate)
                    current = candidate
                }
                let total = dates.count + 1 // incluye la primera
                for d in dates {
                    doseIndex += 1
                    insertEvent(on: d,
                                doseLabel: "dosis \(doseIndex)/\(total)",
                                dewormSeriesID: isDeworming ? dewormSeriesID : nil,
                                rrule: isDeworming ? rrule : nil)
                }
            } else {
                let total = timesPerDay * durationDays
                let hours = 24.0 / Double(timesPerDay)
                for _ in 0..<(total-1) {
                    doseIndex += 1
                    next = cal.date(byAdding: .hour,
                                    value: Int(hours.rounded()),
                                    to: next)!
                    insertEvent(on: next,
                                doseLabel: "dosis \(doseIndex)/\(total)",
                                dewormSeriesID: isDeworming ? dewormSeriesID : nil,
                                rrule: isDeworming ? rrule : nil)
                }
            }
        case .vaccine:
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
                // Omitimos la primera (primary) para mantener consistencia con medicamentos
                var idx = 2
                for d in seriesDates.dropFirst() {
                    insertEvent(on: d, doseLabel: "dosis \(idx)/\(total)")
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
                            // En refuerzo, si se incluye serie corta, también tratamos "extra"
                            let round = generateSeries(
                                start: start,
                                count: vaccineSeriesDoseCount + 1,
                                spacingValue: vaccineSeriesSpacingValue,
                                spacingUnit: vaccineSeriesSpacingUnit
                            )
                            let rTotal = round.count
                            var rIdx = 2
                            for d in round.dropFirst() {
                                insertEvent(on: d, doseLabel: "dosis \(rIdx)/\(rTotal)")
                                rIdx += 1
                            }
                        } else {
                            insertEvent(on: start, doseLabel: nil)
                        }
                    }
                }
            } else {
                // Modo manual: usar fechas provistas (sin etiquetar automáticamente)
                for dose in vaccineDoses.sorted(by: { $0.date < $1.date }) {
                    insertEvent(on: dose.date, doseLabel: nil)
                }
            }
        case .grooming, .weight:
            break
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
    
    // MARK: - Selección de servicios (Grooming)
    func binding(for service: GroomingService) -> Binding<Bool> {
        Binding(
            get: { selectedServices.contains(service) },
            set: { isOn in
                if isOn { selectedServices.insert(service) }
                else { selectedServices.remove(service) }
            }
        )
    }
    
    // MARK: - Generadores de fechas y previsualizaciones
    
    // Agrega un intervalo a una fecha según la unidad
    func addInterval(_ value: Int, unit: IntervalUnit, to date: Date) -> Date {
        let cal = Calendar.current
        switch unit {
        case .hours:
            return cal.date(byAdding: .hour, value: value, to: date) ?? date
        case .days:
            return cal.date(byAdding: .day, value: value, to: date) ?? date
        case .weeks:
            return cal.date(byAdding: .day, value: 7 * value, to: date) ?? date
        case .months:
            return cal.date(byAdding: .month, value: value, to: date) ?? date
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
    
    // Previsualización/Resumen de medicamentos (ambos modos)
    func medicationPreview(start: Date,
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
            // Replica la lógica de scheduleFuture para que coincida
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
    
    func intervalSummary(start: Date,
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
    
    func rrulePreviewString() -> String? {
        guard rruleEnabled else { return nil }
        return makeRRULE(value: rruleIntervalValue, unit: rruleIntervalUnit)
    }
    
    // MARK: - Expansión de RRULE (Desparasitación)
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
        
        // Horizonte: 24 meses a partir de la fecha ancla
        let horizon = Calendar.current.date(byAdding: .month, value: 24, to: anchor) ?? anchor
        
        // Genera fechas (omitimos la ancla; ya está insertada)
        var dates: [Date] = []
        var current = anchor
        while true {
            let next = addInterval(interval, unit: unit, to: current)
            if next > horizon { break }
            dates.append(next)
            current = next
        }
        
        // Evitar duplicados: no insertes si ya hay una Deworming con mismo seriesID y fecha
        for d in dates {
            if !existsDeworming(seriesID: seriesID, date: d, petID: pet.id) {
                // Reusa insertEvent para notificaciones y campos
                _ = insertEvent(on: d, doseLabel: nil, dewormSeriesID: seriesID, rrule: rrule)
            }
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

// MARK: - Quick Add (IA) helpers
private extension EventQuickAddSheet {
    var canSuggestSeries: Bool {
        // Solo tiene sentido para Medicamentos y Vacunas; no para peso/grooming ni desparasitación (tiene RRULE aparte)
        if kind == .weight || kind == .grooming { return false }
        if kind == .medication && isDeworming { return false }
        // Debe haber título o un lastParsed; si no, no sabremos qué sugerir
        return !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lastParsed == nil)
    }
    
    func analyzeQuickAdd() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        quickAddWarning = nil
        quickAddInfo = nil
        lastParsed = nil
        
        let result = await AIEngine.shared.parseQuickAdd(text: quickAddText)
        if let proposed = result.events.first {
            // Mapear tipo detectado → UI
            applyProposedEvent(proposed)
            
            // Auto‑prefill de programación para medicamentos si hay frecuencia “cada X …”
            if proposed.kind == .medication, let (val, unit) = parseFrequencyToInterval(proposed.frequency ?? "") {
                scheduleEnabled = true
                scheduleMode = .interval
                intervalValue = val
                intervalUnit = unit
                // Duración por defecto: 1 día cuando son horas; 7 días si es en días; el usuario puede ajustar
                switch unit {
                case .hours:  durationDays = 1
                case .days:   durationDays = max(1, val)
                case .weeks:  durationDays = 7 * max(1, val)
                case .months: durationDays = 30 * max(1, val)
                }
            }
            
            // Info de confirmación
            let kindText: String = {
                switch proposed.kind {
                case .medication: return "Medicamento"
                case .vaccine:    return "Vacuna"
                case .deworming:  return "Desparasitación"
                case .grooming:   return "Grooming"
                case .weight:     return "Peso"
                }
            }()
            var parts: [String] = [kindText]
            parts.append(proposed.baseName)
            parts.append(proposed.date.formatted(date: .abbreviated, time: .shortened))
            if let d = proposed.dosage, !d.isEmpty { parts.append(d) }
            if let f = proposed.frequency, !f.isEmpty { parts.append(f) }
            if let m = proposed.manufacturer, !m.isEmpty { parts.append("Fab: \(m)") }
            quickAddInfo = parts.joined(separator: " · ")
            lastParsed = proposed
        }
        if let warn = result.warnings.first {
            quickAddWarning = warn
        }
    }
    
    func applyProposedEvent(_ e: ProposedEvent) {
        // Tipo
        let mapping = mapToEventKind(e.kind)
        kind = mapping.kind
        isDeworming = mapping.isDeworming
        
        // Campos comunes
        title = e.baseName
        eventDate = e.date
        
        // Campos específicos
        switch e.kind {
        case .medication:
            dosage = e.dosage ?? ""
            frequency = e.frequency ?? ""
        case .deworming:
            dosage = ""
            frequency = e.frequency ?? ""
        case .vaccine:
            manufacturer = e.manufacturer ?? ""
        case .grooming:
            break
        case .weight:
            break
        }
    }
    
    func mapToEventKind(_ k: ProposedEventKind) -> (kind: EventKind, isDeworming: Bool) {
        switch k {
        case .vaccine:    return (.vaccine, false)
        case .medication: return (.medication, false)
        case .deworming:  return (.medication, true)
        case .grooming:   return (.grooming, false)
        case .weight:     return (.weight, false)
        }
    }
    
    func parseFrequencyToInterval(_ freq: String) -> (Int, IntervalUnit)? {
        let lower = freq.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "cada día" { return (1, .days) }
        if lower == "cada semana" { return (1, .weeks) }
        if lower == "cada mes" { return (1, .months) }
        let parts = lower.split(separator: " ")
        if parts.count >= 3, parts[0] == "cada", let value = Int(parts[1]) {
            let unitStr = parts[2]
            if unitStr.hasPrefix("h") { return (value, .hours) }
            if unitStr.hasPrefix("d") { return (value, .days) }
            if unitStr.hasPrefix("semana") { return (value, .weeks) }
            if unitStr.hasPrefix("mes") { return (value, .months) }
        }
        return nil
        }
    
    func suggestSeries() async {
        isSuggesting = true
        defer { isSuggesting = false }
        
        let proposed: ProposedEvent = {
            if let p = lastParsed { return p }
            let pkind: ProposedEventKind = {
                switch kind {
                case .medication: return isDeworming ? .deworming : .medication
                case .vaccine:    return .vaccine
                case .grooming:   return .grooming
                case .weight:     return .weight
                }
            }()
            return ProposedEvent(kind: pkind,
                                 baseName: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                 fullName: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                 date: eventDate,
                                 dosage: dosage.isEmpty ? nil : dosage,
                                 frequency: frequency.isEmpty ? nil : frequency,
                                 notes: nil,
                                 manufacturer: manufacturer.isEmpty ? nil : manufacturer)
        }()
        
        switch proposed.kind {
        case .medication:
            guard !isDeworming else { return }
            let parsed = parseFrequencyToInterval(proposed.frequency ?? "")
            let hoursInterval: Int? = {
                guard let p = parsed else { return nil }
                switch p.1 {
                case .hours:  return p.0
                case .days:   return p.0 * 24
                case .weeks:  return p.0 * 7 * 24
                case .months: return p.0 * 30 * 24
                }
            }()
            let series = await AIEngine.shared.recommendSeries(for: .medication,
                                                               baseName: proposed.baseName,
                                                               start: proposed.date,
                                                               dosage: proposed.dosage,
                                                               hoursInterval: hoursInterval,
                                                               totalDoses: nil)
            let dates = series.map { $0.date }
            if dates.count >= 2 {
                let delta = dates[1].timeIntervalSince(dates[0])
                let (val, unit) = bestUnitAndValue(for: delta)
                scheduleEnabled = true
                scheduleMode = .interval
                intervalValue = val
                intervalUnit = unit
                let days = max(1, Int(ceil(dates.last!.timeIntervalSince(dates[0]) / (24*3600))))
                durationDays = days
            } else {
                scheduleEnabled = true
                scheduleMode = .interval
                intervalValue = parsed?.0 ?? 8
                intervalUnit = parsed?.1 ?? .hours
                durationDays = 1
            }
            
        case .vaccine:
            let series = await AIEngine.shared.recommendSeries(for: .vaccine,
                                                               baseName: proposed.baseName,
                                                               start: proposed.date,
                                                               dosage: nil,
                                                               hoursInterval: nil,
                                                               totalDoses: nil)
            let dates = series.map { $0.date }.sorted()
            if dates.count >= 2 {
                let delta = dates[1].timeIntervalSince(dates[0])
                let (val, unit) = bestUnitAndValue(for: delta)
                vaccineMode = .automatic
                scheduleEnabled = true
                vaccineSeriesDoseCount = max(1, dates.count - 1)
                vaccineSeriesSpacingValue = val
                vaccineSeriesSpacingUnit = unit == .days ? .weeks : unit
                boostersEnabled = true
                boosterFrequencyValue = 12
                boosterFrequencyUnit = .months
                boosterRoundsCount = 1
            } else {
                vaccineMode = .automatic
                scheduleEnabled = true
                vaccineSeriesDoseCount = 2
                vaccineSeriesSpacingValue = 3
                vaccineSeriesSpacingUnit = .weeks
                boostersEnabled = true
                boosterFrequencyValue = 12
                boosterFrequencyUnit = .months
                boosterRoundsCount = 1
            }
            
        case .grooming, .weight, .deworming:
            break
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func bestUnitAndValue(for interval: TimeInterval) -> (Int, IntervalUnit) {
        let hour: Double = 3600
        let day: Double = 24 * hour
        let week: Double = 7 * day
        if interval < 1.5 * day {
            let hours = Int((interval / hour).rounded())
            return (max(1, hours), .hours)
        } else if interval < 2 * week {
            let days = Int((interval / day).rounded())
            return (max(1, days), .days)
        } else {
            let weeks = Int((interval / week).rounded())
            return (max(1, weeks), .weeks)
        }
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
        EventQuickAddSheet(pet: Pet(name: "Firulais"), initialKind: .medication)
            .modelContainer(for: Pet.self, inMemory: true)
    }
}

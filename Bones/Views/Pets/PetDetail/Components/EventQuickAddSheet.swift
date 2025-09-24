//
//  EventQuickAddSheet.swift
//  Bones
//

import SwiftUI
import SwiftData

// MARK: - Tipos de evento
enum EventKind: String, CaseIterable, Identifiable {
    case medication  = "Medicamento"
    case vaccine     = "Vacuna"
    case deworming   = "Desparasitación"
    case grooming    = "Grooming"
    case weight      = "Peso"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .medication: "pills.fill"
        case .vaccine:    "syringe"
        case .deworming:  "bandage.fill"
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
    
    // Init
    init(pet: Pet, initialKind: EventKind = .medication) {
        self.pet = pet
        _kind = State(initialValue: initialKind)
    }
    
    // ----------------- Estado -----------------
    @State private var kind: EventKind
    
    // Comunes
    @State private var title = ""
    @State private var eventDate = Date().addingTimeInterval(60*60)
    
    // Medicamento
    @State private var dosage = ""
    @State private var frequency = ""
    
    // Vacuna
    @State private var manufacturer = ""
    
    // Grooming
    @State private var location = ""
    
    // Peso
    @State private var weightKg = ""
    
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
    
    // — Desparasitación —
    @State private var dewormIntervalVal = 1
    @State private var dewormIntervalUnit: IntervalUnit = .months
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    
    var body: some View {
        NavigationStack {
            Form {
                // ---------- Tipo ----------
                TypeChips
                
                // ---------- Detalles ----------
                Section("Detalles") { detailsSection }
                
                // ---------- Fecha ----------
                Section("Fecha") {
                    DatePicker("Primera dosis",
                               selection: $eventDate,
                               displayedComponents: [.date, .hourAndMinute])
                }
                
                // ---------- Programación futura ----------
                futureScheduleSection
            }
            .navigationTitle("Nuevo evento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveEvent() }
                        .disabled(kind != .weight && title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if kind == .vaccine && vaccineMode == .manual && vaccineDoses.isEmpty {
                    if let m1 = Calendar.current.date(byAdding: .month, value: 1,
                                                      to: eventDate) {
                        vaccineDoses = [VaccineDose(date: m1)]
                    }
                }
            }
        }
    }
}

// MARK: - Sub-vistas UI
private extension EventQuickAddSheet {
    
    var TypeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventKind.allCases) { k in
                    Button { kind = k } label: {
                        Label(k.rawValue, systemImage: k.icon)
                            .font(.subheadline)
                            .padding(.vertical,6).padding(.horizontal,12)
                            .background(Capsule().fill(kind == k ? Color.accentColor
                                                                 : Color(.systemGray5)))
                            .foregroundStyle(kind == k ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }.padding(.horizontal)
        }.padding(.vertical,4)
    }
    
    @ViewBuilder var detailsSection: some View {
        switch kind {
        case .medication:
            TextField("Nombre del medicamento", text: $title)
            TextField("Dosis (ej. 10 mg)", text: $dosage)
        case .vaccine:
            TextField("Nombre de la vacuna", text: $title)
            TextField("Fabricante", text: $manufacturer)
        case .deworming:
            TextField("Descripción", text: $title)
        case .grooming:
            TextField("Descripción", text: $title)
            TextField("Lugar", text: $location)
        case .weight:
            TextField("Peso (kg)", text: $weightKg)
                .keyboardType(.decimalPad)
        }
    }
    
    @ViewBuilder var futureScheduleSection: some View {
        if kind == .medication || kind == .vaccine || kind == .deworming {
            Section {
                Toggle("Programar próximas dosis", isOn: $scheduleEnabled)
                
                if scheduleEnabled {
                    if kind == .medication { medicationControls }
                    if kind == .vaccine   { vaccineControls }
                    if kind == .deworming { dewormControls }
                }
            }
        }
    }
    
    // ---- Medicamentos ----
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
    
    // ---- Desparasitación ----
    var dewormControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            IntervalRow(value: $dewormIntervalVal, unit: $dewormIntervalUnit)
            DatePicker("Hasta", selection: $endDate, displayedComponents: .date)
            
            // Resumen en vivo para desparasitación
            if let summary = dewormingSummary(
                start: eventDate,
                end: endDate,
                stepValue: dewormIntervalVal,
                stepUnit: dewormIntervalUnit
            ) {
                Text("Se crearán \(summary.total) dosis en total. Última: \(summary.last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

// MARK: - Guardado
extension EventQuickAddSheet {
    
    private func saveEvent() {
        let primary = insertEvent(on: eventDate, doseLabel: nil)
        if scheduleEnabled { scheduleFuture(from: primary) }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        dismiss()
    }
    
    @discardableResult
    private func insertEvent(on date: Date,
                             doseLabel: String?) -> any BasicEvent {
        switch kind {
        case .medication:
            let name = doseLabel.map { "\(title) (\($0))" } ?? title
            let m = Medication(date: date, pet: pet,
                               name: name, dosage: dosage, frequency: frequency)
            context.insert(m)
            notify(id: m.id, title: "Medicamento",
                   body: "\(pet.name) – \(name)", at: date)
            return m
        case .vaccine:
            // Etiquetamos dosis X/Y cuando corresponda
            let name = doseLabel.map { "\(title) (\($0))" } ?? title
            let v = Vaccine(date: date, pet: pet,
                            vaccineName: name, manufacturer: manufacturer)
            context.insert(v)
            notify(id: v.id, title: "Vacuna",
                   body: "\(pet.name) – \(title)", at: date)
            return v
        case .deworming:
            let d = Deworming(date: date, pet: pet, notes: title)
            context.insert(d)
            notify(id: d.id, title: "Desparasitación",
                   body: pet.name, at: date)
            return d
        case .grooming:
            let g = Grooming(date: date, pet: pet,
                             location: location, notes: title)
            context.insert(g)
            notify(id: g.id, title: "Grooming",
                   body: pet.name, at: date)
            return g
        case .weight:
            let kg = Double(weightKg) ?? 0
            let w = WeightEntry(date: date, pet: pet, weightKg: kg)
            context.insert(w)
            return w
        }
    }
    
    private func scheduleFuture(from primary: any BasicEvent) {
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
                    insertEvent(on: d, doseLabel: "dosis \(doseIndex)/\(total)")
                }
            } else {
                let total = timesPerDay * durationDays
                let hours = 24.0 / Double(timesPerDay)
                for _ in 0..<(total-1) {
                    doseIndex += 1
                    next = cal.date(byAdding: .hour,
                                    value: Int(hours.rounded()),
                                    to: next)!
                    insertEvent(on: next, doseLabel: "dosis \(doseIndex)/\(total)")
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
                // Manual: usar fechas provistas (sin etiquetar automáticamente)
                for dose in vaccineDoses.sorted(by: { $0.date < $1.date }) {
                    insertEvent(on: dose.date, doseLabel: nil)
                }
            }
        case .deworming:
            while true {
                next = add(dewormIntervalVal, dewormIntervalUnit, to: next)
                if next > endDate { break }
                insertEvent(on: next, doseLabel: nil)
            }
        default: break
        }
    }
    
    private func notify(id: UUID, title: String, body: String, at date: Date) {
        NotificationManager.shared.scheduleNotification(
            id: id, title: title, body: body, fireDate: date, advance: 0)
    }
}

// MARK: - Helpers de cálculo (resumen en UI y vacunas)
private extension EventQuickAddSheet {
    // Medicamentos por intervalo (duración en días)
    func intervalSummary(start: Date,
                         durationDays: Int,
                         stepValue: Int,
                         stepUnit: IntervalUnit) -> (total: Int, last: Date)? {
        guard durationDays > 0, stepValue > 0 else { return nil }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: durationDays, to: start)!
        
        var count = 1 // incluye la primera
        var last = start
        while true {
            let next = {
                switch stepUnit {
                case .hours:  cal.date(byAdding: .hour, value: stepValue, to: last)!
                case .days:   cal.date(byAdding: .day, value: stepValue, to: last)!
                case .weeks:  cal.date(byAdding: .day, value: 7 * stepValue, to: last)!
                case .months: cal.date(byAdding: .month, value: stepValue, to: last)!
                }
            }()
            if next > end { break }
            count += 1
            last = next
        }
        return (count, last)
    }
    
    // Desparasitación (fecha fin exacta)
    func dewormingSummary(start: Date,
                          end: Date,
                          stepValue: Int,
                          stepUnit: IntervalUnit) -> (total: Int, last: Date)? {
        guard end > start, stepValue > 0 else { return nil }
        let cal = Calendar.current
        var count = 1
        var last = start
        while true {
            let next = {
                switch stepUnit {
                case .hours:  cal.date(byAdding: .hour, value: stepValue, to: last)!
                case .days:   cal.date(byAdding: .day, value: stepValue, to: last)!
                case .weeks:  cal.date(byAdding: .day, value: 7 * stepValue, to: last)!
                case .months: cal.date(byAdding: .month, value: stepValue, to: last)!
                }
            }()
            if next > end { break }
            count += 1
            last = next
        }
        return (count, last)
    }
    
    // Vacunas: generar una serie de N dosis con separación
    func generateSeries(start: Date,
                        count: Int,
                        spacingValue: Int,
                        spacingUnit: IntervalUnit) -> [Date] {
        let cal = Calendar.current
        guard count >= 1 else { return [] }
        var dates = [start]
        var last = start
        for _ in 1..<count {
            let next: Date
            switch spacingUnit {
            case .hours:  next = cal.date(byAdding: .hour, value: spacingValue, to: last)!
            case .days:   next = cal.date(byAdding: .day, value: spacingValue, to: last)!
            case .weeks:  next = cal.date(byAdding: .day, value: 7 * spacingValue, to: last)!
            case .months: next = cal.date(byAdding: .month, value: spacingValue, to: last)!
            }
            dates.append(next)
            last = next
        }
        return dates
    }
    
    // Vacunas: fechas de inicio de cada refuerzo
    func generateBoosterStarts(start: Date,
                               rounds: Int,
                               freqValue: Int,
                               freqUnit: IntervalUnit) -> [Date] {
        let cal = Calendar.current
        guard rounds >= 1 else { return [] }
        var starts: [Date] = []
        var last = start
        for _ in 0..<rounds {
            let next: Date
            switch freqUnit {
            case .hours:  next = cal.date(byAdding: .hour, value: freqValue, to: last)!
            case .days:   next = cal.date(byAdding: .day, value: freqValue, to: last)!
            case .weeks:  next = cal.date(byAdding: .day, value: 7 * freqValue, to: last)!
            case .months: next = cal.date(byAdding: .month, value: freqValue, to: last)!
            }
            starts.append(next)
            last = next
        }
        return starts
    }
    
    // Vacunas: previsualización combinada
    func vaccinePreview(start: Date,
                        seriesCount: Int, // "extra"
                        seriesSpacingValue: Int,
                        seriesSpacingUnit: IntervalUnit,
                        boostersEnabled: Bool,
                        boosterFreqValue: Int,
                        boosterFreqUnit: IntervalUnit,
                        boosterRounds: Int,
                        boosterIncludesSeries: Bool) -> VaccinePreview? {
        // Convertimos "extra" a "total" sumando la inicial
        let totalSeriesCount = max(1, seriesCount + 1)
        let series = generateSeries(start: start,
                                    count: totalSeriesCount,
                                    spacingValue: seriesSpacingValue,
                                    spacingUnit: seriesSpacingUnit)
        var rounds: [[Date]] = []
        if boostersEnabled {
            let starts = generateBoosterStarts(start: start,
                                               rounds: boosterRounds,
                                               freqValue: boosterFreqValue,
                                               freqUnit: boosterFreqUnit)
            for s in starts {
                if boosterIncludesSeries {
                    rounds.append(generateSeries(start: s,
                                                 count: totalSeriesCount,
                                                 spacingValue: seriesSpacingValue,
                                                 spacingUnit: seriesSpacingUnit))
                } else {
                    rounds.append([s])
                }
            }
        }
        return VaccinePreview(seriesDates: series, boosterRounds: rounds)
    }
}

#Preview {
    NavigationStack {
        EventQuickAddSheet(pet: Pet(name: "Firulais"), initialKind: .vaccine)
            .modelContainer(for: Pet.self, inMemory: true)
    }
}

//
//  PetWeightTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData
import Charts        // iOS 16+
import UIKit         // Haptics

struct PetWeightTab: View {
    let pet: Pet
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    // Hoja para nuevo peso
    @State private var showingAdd = false
    @State private var newWeight = ""
    @State private var newDate = Date()
    @State private var newNotes = ""
    @State private var inputUnit: InputUnit = .kg
    
    // Rango (sin media móvil)
    @State private var range: ChartRange = .threeMonths
    
    // Interacción del gráfico (callout)
    @State private var selectedDate: Date? = nil
    
    // Forzar refresco tras guardar o borrar
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(spacing: 0) {
            // ---------- Encabezado minimal ----------
            header
            
            // ---------- Todo lo demás dentro del scroll ----------
            List {
                if viewModel.weights.isEmpty {
                    // Estado vacío único (emoji + texto)
                    Section {
                        ContentUnavailableView("Sin registros de peso", systemImage: "scalemass")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowInsets(.init(top: 16, leading: 0, bottom: 16, trailing: 0))
                    }
                } else {
                    // Selector de rango + gráfica dentro del scroll
                    if filteredWeights.count >= 2 {
                        Section {
                            controls
                            chartView
                                .id(refreshID)
                        }
                    }
                    
                    // KPIs del rango (si quieres mantenerlos también aquí)
//                    if let stats = rangeStats {
//                        Section {
//                            rangeKPIs(stats: stats)
//                        }
//                    }
                    
                    // Registros históricos
                    Section("Registros") {
                        ForEach(viewModel.weights, id: \.id) { entry in
                            NavigationLink {
                                EventDetailView(event: entry)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.date, format: .dateTime.day().month().year())
                                        Text(entry.date, format: .dateTime.hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if let notes = entry.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    Text(String(format: "%.1f kg", entry.weightKg))
                                        .font(.headline)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Peso \(String(format: "%.1f", entry.weightKg)) kilogramos, \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                        }
                        .onDelete { indices in
                            for idx in indices {
                                let entry = viewModel.weights[idx]
                                context.delete(entry)
                            }
                            try? context.save()
                            refreshID = UUID()
                        }
                    }
                }
                
                // Botón “Añadir peso” AL FINAL (comentado a petición)
                /*
                Section {
                    Button {
                        prepareAddSheet()
                        showingAdd = true
                    } label: {
                        Label("Añadir peso", systemImage: "plus.circle.fill")
                    }
                }
                */
            }
        }
        .sheet(isPresented: $showingAdd) { addSheet }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            // Refresca gráfico/lista tras editar en el detalle
            refreshID = UUID()
        }
    }
}

// MARK: - Tipos y helpers internos

private enum ChartRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1A"
    case all = "Todo"
    
    var id: Self { self }
    var label: String { rawValue }
    
    func startDate(from now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .oneMonth:
            return cal.date(byAdding: .month, value: -1, to: now)
        case .threeMonths:
            return cal.date(byAdding: .month, value: -3, to: now)
        case .sixMonths:
            return cal.date(byAdding: .month, value: -6, to: now)
        case .oneYear:
            return cal.date(byAdding: .year, value: -1, to: now)
        case .all:
            return nil
        }
    }
}

private struct RangeStats {
    let min: Double
    let max: Double
    let avg: Double
}

// MARK: - Subvistas y propiedades calculadas

private extension PetWeightTab {
    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let last = viewModel.currentWeight {
                // Fila 1: Actual (peso) + "Última" (hace X)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peso Actual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack{
                            Text(String(format: "%.1f kg", last.weightKg))
                                .font(.title3.monospacedDigit())
                                .fontWeight(.semibold)
                            HStack(alignment: .firstTextBaseline) {
                                Text("delta: \(viewModel.deltaDescription)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Último registro")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(last.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Fila 2: Δ + KPIs del rango + chip del rango
                HStack(alignment: .firstTextBaseline) {

                    
                    if let stats = rangeStats {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mín.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", stats.min))
                                    .font(.footnote.monospacedDigit())
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prom.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", stats.avg))
                                    .font(.footnote.monospacedDigit())
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Máx.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", stats.max))
                                    .font(.footnote.monospacedDigit())
                            }
                            
                            Text(range.label)
                                .font(.caption2)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(Capsule().fill(Color(.systemGray5)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Sin registros")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    var controls: some View {
        HStack {

            Picker("", selection: $range) {
                ForEach(ChartRange.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)

        }
    }
    
    var chartView: some View {
        Chart {
            ForEach(filteredWeights, id: \.id) { entry in
                LineMark(
                    x: .value("Fecha", entry.date),
                    y: .value("Peso (kg)", entry.weightKg)
                )
                .interpolationMethod(.catmullRom)
                // .foregroundStyle(.accent) // usa color por defecto del sistema
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
    }
    
    var filteredWeights: [WeightEntry] {
        let all = viewModel.weights
        guard let start = range.startDate() else {
            // Todo – devolver ascendente para el gráfico
            return all.sorted { $0.date < $1.date }
        }
        return all
            .filter { $0.date >= start }
            .sorted { $0.date < $1.date }
    }
    
    var rangeStats: RangeStats? {
        let values = filteredWeights.map { $0.weightKg }
        guard !values.isEmpty else { return nil }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let avgV = values.reduce(0, +) / Double(values.count)
        return RangeStats(min: minV, max: maxV, avg: avgV)
    }
    
    func rangeKPIs(stats: RangeStats) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Mín.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f kg", stats.min))
                    .font(.headline.monospacedDigit())
            }
            Spacer()
            VStack(alignment: .center) {
                Text("Prom.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f kg", stats.avg))
                    .font(.headline.monospacedDigit())
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Máx.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f kg", stats.max))
                    .font(.headline.monospacedDigit())
            }
        }
    }
    
    var addSheet: some View {
        NavigationStack {
            Form {
                Section("Medición") {
                    HStack {
                        TextField("Peso", text: $newWeight)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        Picker("", selection: $inputUnit) {
                            ForEach(InputUnit.allCases) { u in
                                Text(u.symbol).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 140)
                    }
                    
                    DatePicker("Fecha y hora",
                               selection: $newDate,
                               displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Notas (opcional)", text: $newNotes, axis: .vertical)
                        .lineLimit(1...4)
                }
                
                if let warning = validationMessageWeight() {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Nuevo peso")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showingAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveNewWeight() }
                        .disabled(!canSaveWeight())
                }
            }
        }
    }
}

// MARK: - Guardado y validación

private extension PetWeightTab {
    func prepareAddSheet() {
        // Prefill con último peso
        if let last = viewModel.currentWeight?.weightKg {
            let value = inputUnit.fromKilograms(last)
            newWeight = String(format: "%.1f", value)
        } else {
            newWeight = ""
        }
        newDate = Date()
        newNotes = ""
    }
    
    func saveNewWeight() {
        guard let val = parseLocalizedDouble(newWeight), val > 0 else { return }
        let kg = inputUnit.toKilograms(val)
        let entry = WeightEntry(date: newDate, pet: pet, weightKg: kg, notes: newNotes.isEmpty ? nil : newNotes)
        context.insert(entry)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        refreshID = UUID()
        showingAdd = false
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
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
    
    func speciesRange() -> (min: Double, max: Double) {
        switch pet.species {
        case .perro: return (0.5, 120.0)
        case .gato:  return (0.5, 15.0)
        }
    }
    
    func canSaveWeight() -> Bool {
        guard let val = parseLocalizedDouble(newWeight), val > 0 else { return false }
        let (minV, maxV) = speciesRange()
        let kg = inputUnit.toKilograms(val)
        return kg >= minV && kg <= maxV
    }
    
    func validationMessageWeight() -> String? {
        guard let val = parseLocalizedDouble(newWeight), val > 0 else {
            return "Introduce un peso válido mayor que 0."
        }
        let (minV, maxV) = speciesRange()
        let kg = inputUnit.toKilograms(val)
        if kg < minV || kg > maxV {
            return "Valor fuera de rango para \(pet.species == .perro ? "perro" : "gato"): \(String(format: "%.1f", minV))–\(String(format: "%.1f", maxV)) kg."
        }
        return nil
    }
}

// MARK: - Previews

private enum WeightTabPreviewData {
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
    
    @discardableResult
    static func seedWeights(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        
        // Serie de pesos en los últimos 6 meses
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -6, to: now)!
        var base: Double = 22.0
        
        for i in 0..<18 { // cada ~10 días
            if let date = cal.date(byAdding: .day, value: i * 10, to: start) {
                // Simulación con ligera tendencia y ruido
                let delta = Double(i) * 0.12
                let noise = sin(Double(i) / 2.5) * 0.4
                let kg = max(10.0, base + delta + noise)
                let entry = WeightEntry(date: date, pet: pet, weightKg: kg, notes: i % 3 == 0 ? "Control" : nil)
                ctx.insert(entry)
            }
        }
        
        try? ctx.save()
        return pet
    }
    
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }
}

private struct PetWeightTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        PetWeightTab(pet: pet, viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

#Preview("Peso – Demo") {
    let container = WeightTabPreviewData.makeContainer()
    let pet = WeightTabPreviewData.seedWeights(in: container)
    return PetWeightTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Peso – Vacío") {
    let container = WeightTabPreviewData.makeContainer()
    let pet = WeightTabPreviewData.emptyPet(in: container)
    return PetWeightTabPreviewHost(pet: pet)
        .modelContainer(container)
}

//
//  PetHealthTab.swift
//  Bones
//
//  Created by Felipe Duarte on 29/09/25.
//


import SwiftUI
import SwiftData

struct PetHealthTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    
    enum HealthSegment: String, CaseIterable, Identifiable {
        case vaccines     = "Vacunas"
        case deworm       = "Desparasitación"
        case medications  = "Medicamentos"
        var id: Self { self }
    }
    
    @Binding var segment: HealthSegment
    
    init(viewModel: PetDetailViewModel, segment: Binding<HealthSegment>) {
        self._segment = segment
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Selector interno
            Picker("", selection: $segment) {
                ForEach(HealthSegment.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
            
            // Contenido
            switch segment {
            case .vaccines:
                PetVaccinesTab(viewModel: viewModel)
            case .deworm:
                PetDewormingTab(viewModel: viewModel)
            case .medications:
                PetMedicationsTab(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Previews

#Preview("Salud – Vacunas/Desparasitación/Medicamentos") {
    let container = HealthPreviewData.makeContainer()
    let pet = HealthPreviewData.seedHealthData(in: container)
    return PetHealthTabPreviewHost(pet: pet)
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Salud – Vacío") {
    let container = HealthPreviewData.makeContainer()
    let pet = HealthPreviewData.emptyPet(in: container)
    return PetHealthTabPreviewHost(pet: pet)
        .modelContainer(container)
        .environment(\.locale, Locale(identifier: "es"))
}

// Host que crea el VM y le inyecta el context del entorno
private struct PetHealthTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    @State private var segment: PetHealthTab.HealthSegment = .vaccines
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        NavigationStack {
            PetHealthTab(viewModel: vm, segment: $segment)
        }
        .onAppear {
            vm.inject(context: context)
        }
    }
}

// Datos de ejemplo para previews
private enum HealthPreviewData {
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
    
    // Pet sin datos de salud
    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }
    
    // Pet con vacunas, desparasitación (CO) y algunos medicamentos
    @discardableResult
    static func seedHealthData(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        
        let now = Date()
        let cal = Calendar.current
        
        // ---------- Vacunas (igual que antes, variado) ----------
        let v0 = Vaccine(date: now.addingTimeInterval(-10 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Rabia (dosis 0/3)",
                         manufacturer: "VetLabs",
                         notes: "Dosis previa")
        v0.isCompleted = true
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
        let v3 = Vaccine(date: now.addingTimeInterval(5 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Moquillo",
                         manufacturer: nil,
                         notes: "Aplicar por la mañana")
        let v4 = Vaccine(date: now.addingTimeInterval(-3 * 24 * 3600),
                         pet: pet,
                         vaccineName: "Parvovirus",
                         manufacturer: "",
                         notes: "Control")
        
        // ---------- Desparasitación (CO) ----------
        // 1) Drontal Plus — hoy + 15 días (2/2), luego refuerzo a 3 meses
        let seriesDrontal = UUID()
        let dr1 = Deworming(date: now,
                            pet: pet,
                            notes: "Drontal Plus (dosis 1/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesDrontal)
        dr1.isCompleted = true
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
        
        // 2) Endogard — hoy + 15 días (2/2), luego cada 3 meses
        let seriesEndogard = UUID()
        let en1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!,
                            pet: pet,
                            notes: "Endogard (dosis 1/2)",
                            prescriptionImageData: nil,
                            seriesID: seriesEndogard)
        en1.isCompleted = true
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
        
        // 3) Panacur (fenbendazol) — 3 días seguidos y repetir el ciclo a 14 días
        let seriesPanacur = UUID()
        let p1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                           pet: pet,
                           notes: "Panacur (dosis 1/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesPanacur)
        p1.isCompleted = true
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
        
        // ---------- Medicamentos (algunos próximos y otros pasados) ----------
        let m1 = Medication(date: now.addingTimeInterval(6 * 3600),
                            pet: pet,
                            name: "Amoxicilina (dosis 1/3)",
                            dosage: "250 mg",
                            frequency: "")
        let m2 = Medication(date: now.addingTimeInterval(14 * 3600),
                            pet: pet,
                            name: "Amoxicilina (dosis 2/3)",
                            dosage: "250 mg",
                            frequency: "")
        let m3 = Medication(date: now.addingTimeInterval(-8 * 3600),
                            pet: pet,
                            name: "Omeprazol",
                            dosage: "20 mg",
                            frequency: "cada día")
        m3.isCompleted = true
        
        // Insertar todo
        [v0, v1, v2, v3, v4].forEach { ctx.insert($0) }
        [dr1, dr2, drBooster,
         en1, en2, enBooster,
         p1, p2, p3, pR1, pR2, pR3,
         mi1, mi2, miNext].forEach { ctx.insert($0) }
        [m1, m2, m3].forEach { ctx.insert($0) }
        
        try? ctx.save()
        return pet
    }
}


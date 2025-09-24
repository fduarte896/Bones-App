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
    
    var body: some View {
        List {
            if viewModel.medications.isEmpty {
                ContentUnavailableView("Sin medicamentos registrados",
                                       systemImage: "pills.fill")
            } else {
                ForEach(viewModel.medications, id: \.id) { med in
                    MedicationRow(med: med, context: context, viewModel: viewModel)
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }   // refresca si usas propiedad @Published
    }
}

// MARK: - Fila
private struct MedicationRow: View {
    @Bindable var med: Medication            // Bindable para actualizar isCompleted
    var context: ModelContext
    var viewModel: PetDetailViewModel
    
    // Separa "Nombre (dosis X/Y)" en (base: "Nombre", dose: "Dosis X/Y")
    private func splitDose(from name: String) -> (base: String, dose: String?) {
        // Buscamos un sufijo del tipo " (dosis X/Y)" al final del string
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        // El paréntesis de apertura
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1) // apunta a "("
        // El paréntesis de cierre al final
        let closingParenIndex = name.index(before: name.endIndex)            // apunta a ")"
        guard closingParenIndex > openParenIndex else {
            return (name, nil)
        }
        let contentStart = name.index(after: openParenIndex) // después de "("
        let contentEnd   = closingParenIndex                 // antes de ")"
        let inside = String(name[contentStart..<contentEnd]) // "dosis X/Y"
        
        // Validamos que realmente sea "dosis N/M"
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            // Capitalizamos "Dosis" para mostrar como etiqueta
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
    
    var body: some View {
        let parsed = splitDose(from: med.name)
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Nombre del medicamento (sin el sufijo de dosis)
                Text(parsed.base).fontWeight(.semibold)
                
                // Línea dedicada al número de la dosis (si aplica)
                if let doseLabel = parsed.dose {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Dosis y frecuencia
                Text("Dosis: \(med.dosage)  \(med.frequency)")
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
        .swipeActions(edge: .leading) {
            Button {
                med.isCompleted.toggle()
                try? context.save()
            } label: {
                Label("Completar", systemImage: "checkmark")
            }.tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: med.id)
                context.delete(med)
                try? context.save()
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}


//#Preview {
//    PetMedicationsTab()
//}

#Preview("PetMedicationsTab – Demo") {
    // 1) Contenedor en memoria con el esquema necesario
    let container = PreviewData.makeContainer()
    // 2) Insertamos datos de ejemplo y recibimos la mascota
    let pet = PreviewData.samplePet(in: container)
    
    // 3) Host que crea e inyecta el ViewModel con el context del entorno
    return PetMedicationsTabPreviewHost(pet: pet)
        .modelContainer(container)
}

// MARK: - Preview Host
private struct PetMedicationsTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel
    
    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }
    
    var body: some View {
        PetMedicationsTab(viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

// MARK: - Preview Data Helper
private enum PreviewData {
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
        let container = try! ModelContainer(for: schema, configurations: config)
        return container
    }
    
    @discardableResult
    static func samplePet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky")
        ctx.insert(pet)
        
        let base = Date().addingTimeInterval(60 * 60) // +1h
        let m1 = Medication(date: base,
                            pet: pet,
                            name: "Amoxicilina (dosis 2/5)",
                            dosage: "250 mg",
                            frequency: "cada 8 h")
        let m2 = Medication(date: base.addingTimeInterval(8 * 3600),
                            pet: pet,
                            name: "Amoxicilina (dosis 3/5)",
                            dosage: "250 mg",
                            frequency: "cada 8 h")
        let m3 = Medication(date: base.addingTimeInterval(2 * 24 * 3600),
                            pet: pet,
                            name: "Omeprazol",
                            dosage: "10 mg",
                            frequency: "cada día")
        
        ctx.insert(m1)
        ctx.insert(m2)
        ctx.insert(m3)
        try? ctx.save()
        return pet
    }
}

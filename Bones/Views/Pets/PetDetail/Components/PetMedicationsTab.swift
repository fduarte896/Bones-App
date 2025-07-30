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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).fontWeight(.semibold)
                Text("Dosis: \(med.dosage)  \(med.frequency)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

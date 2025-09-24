//
//  PetVaccinesTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetVaccinesTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    var body: some View {
        List {
            if viewModel.vaccines.isEmpty {
                ContentUnavailableView("Sin vacunas registradas",
                                       systemImage: "syringe")
            } else {
                ForEach(viewModel.vaccines, id: \.id) { vac in
                    VaccineRow(vac: vac, context: context, viewModel: viewModel)
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }   // refresca si usas @Published
    }
}

// MARK: - Fila
private struct VaccineRow: View {
    @Bindable var vac: Vaccine
    var context: ModelContext
    var viewModel: PetDetailViewModel
    
    // Extrae " (dosis X/Y)" del nombre si existe
    private func splitDose(from name: String) -> (base: String, dose: String?) {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1) // "("
        let closingParenIndex = name.index(before: name.endIndex)            // ")"
        guard closingParenIndex > openParenIndex else { return (name, nil) }
        let contentStart = name.index(after: openParenIndex)
        let contentEnd   = closingParenIndex
        let inside = String(name[contentStart..<contentEnd]) // "dosis X/Y"
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
    
    var body: some View {
        let parsed = splitDose(from: vac.vaccineName)
        
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.base).fontWeight(.semibold)
                
                if let doseLabel = parsed.dose {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let m = vac.manufacturer, !m.isEmpty {
                    Text("Fabricante: \(m)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(vac.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: vac.isCompleted ? "checkmark.circle.fill"
                                              : "syringe")
                .foregroundStyle(vac.isCompleted ? .green : .accentColor)
        }
        .swipeActions(edge: .leading) {
            Button {
                vac.isCompleted.toggle()
                try? context.save()
            } label: {
                Label("Completar", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: vac.id)
                context.delete(vac)
                try? context.save()
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}


//#Preview {
//    PetVaccinesTab()
//}

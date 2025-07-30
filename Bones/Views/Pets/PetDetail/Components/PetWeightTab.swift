//
//  PetWeightTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData
import Charts        // iOS 16+

struct PetWeightTab: View {
    let pet: Pet
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    // Mostrar hoja para nuevo peso
    @State private var showingAdd = false
    @State private var newWeight = ""
    @State private var newDate = Date()
    
    var body: some View {
        VStack {
            // ---------- Encabezado ----------
            if let last = viewModel.currentWeight {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f kg", last.weightKg))
                        .font(.system(.largeTitle, weight: .bold))
                    Text(viewModel.deltaDescription)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(last.date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                ContentUnavailableView("Sin registros de peso",
                                       systemImage: "scalemass")
            }
            
            // ---------- Gráfico ----------
            if viewModel.weights.count >= 2 {
                Chart {
                    ForEach(viewModel.weights.reversed(), id: \.id) { entry in
                        LineMark(
                            x: .value("Fecha", entry.date),
                            y: .value("Peso", entry.weightKg)
                        )
                        PointMark(
                            x: .value("Fecha", entry.date),
                            y: .value("Peso", entry.weightKg)
                        )
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 160)
                .padding(.horizontal)
            }
            
            // ---------- Lista histórica ----------
            List {
                ForEach(viewModel.weights, id: \.id) { entry in
                    HStack {
                        Text(entry.date, format: .dateTime.day().month())
                        Spacer()
                        Text(String(format: "%.1f kg", entry.weightKg))
                    }
                }
                .onDelete { indices in
                    for idx in indices {
                        let entry = viewModel.weights[idx]
                        context.delete(entry)
                    }
                    try? context.save()
                }
            }
        }
    }
    
    // Guardar entrada
    private func saveWeight() {
        guard let kg = Double(newWeight) else { return }
        let w = WeightEntry(date: newDate, pet: pet, weightKg: kg)
        context.insert(w)
        try? context.save()
        showingAdd = false
        newWeight = ""
        newDate = Date()
    }
}

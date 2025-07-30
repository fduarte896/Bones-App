//
//  PetDewormingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetDewormingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    var body: some View {
        List {
            if viewModel.dewormings.isEmpty {
                ContentUnavailableView("Sin desparasitaciones registradas",
                                       systemImage: "bandage.fill")
            } else {
                ForEach(viewModel.dewormings, id: \.id) { dew in
                    DewormingRow(dew: dew, context: context)
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
    }
}

// MARK: - Fila
private struct DewormingRow: View {
    @Bindable var dew: Deworming
    var context: ModelContext
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación")
                    .fontWeight(.semibold)
                Text(dew.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: dew.isCompleted ? "checkmark.circle.fill"
                                              : "bandage.fill")
                .foregroundStyle(dew.isCompleted ? .green : .accentColor)
        }
        // Swipe: completar
        .swipeActions(edge: .leading) {
            Button {
                dew.isCompleted.toggle()
                try? context.save()
            } label: { Label("Completar", systemImage: "checkmark") }
            .tint(.green)
        }
        // Swipe: borrar
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: dew.id)
                context.delete(dew)
                try? context.save()
            } label: { Label("Borrar", systemImage: "trash") }
        }
    }
}

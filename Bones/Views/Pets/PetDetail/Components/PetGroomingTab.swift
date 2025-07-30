//
//  PetGroomingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetGroomingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context
    
    var body: some View {
        List {
            if viewModel.groomings.isEmpty {
                ContentUnavailableView("Sin citas de grooming",
                                       systemImage: "scissors")
            } else {
                ForEach(viewModel.groomings, id: \.id) { groom in
                    GroomingRow(groom: groom, context: context, viewModel: viewModel)
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
    }
}

// MARK: - Fila
private struct GroomingRow: View {
    @Bindable var groom: Grooming
    var context: ModelContext
    var viewModel: PetDetailViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Descripción principal: usa notes o texto genérico
                Text(groom.notes?.isEmpty == false ? groom.notes! : "Sesión de grooming")
                    .fontWeight(.semibold)
                
                // Ubicación, si existe
                if let loc = groom.location, !loc.isEmpty {
                    Text("Lugar: \(loc)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Fecha / hora
                Text(groom.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: groom.isCompleted ? "checkmark.circle.fill" : "scissors")
                .foregroundStyle(groom.isCompleted ? .green : .accentColor)
        }
        // Swipe: completar
        .swipeActions(edge: .leading) {
            Button {
                groom.isCompleted.toggle()
                try? context.save()
            } label: {
                Label("Completar", systemImage: "checkmark")
            }.tint(.green)
        }
        // Swipe: borrar
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: groom.id)
                context.delete(groom)
                try? context.save()
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }
}

//
//  PetUpcomingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//

import SwiftUI
import SwiftData

struct PetUpcomingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            if viewModel.groupedUpcomingEvents.isEmpty {
                ContentUnavailableView("Sin próximos eventos",
                                       systemImage: "checkmark.circle")
            } else {
                ForEach(viewModel.groupedUpcomingEvents) { section in
                    Section(section.title){
                        ForEach(section.items, id: \.id) { event in
                            EventRow(event: event, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.fetchEvents() }
    }
}

private struct EventRow: View {
    let event: any BasicEvent
    @Environment(\.modelContext) var context
    var viewModel: PetDetailViewModel   // para refrescar
    
    // Separa " (dosis X/Y)" en cualquier displayName
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
        let parsed = splitDose(from: event.displayName)
    
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Título sin sufijo de dosis
                Text(parsed.base).fontWeight(.semibold)
                
                // Línea dedicada al número de la dosis (si aplica)
                if let doseLabel = parsed.dose {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !event.displayType.isEmpty {
                    Text(event.displayType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(event.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "bell")
        }
        // Swipe: borrar
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                NotificationManager.shared.cancelNotification(id: event.id)
                context.delete(event)
                try? context.save()
                viewModel.fetchEvents()
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
        // Swipe: completar
        .swipeActions(edge: .leading) {
            Button {
                event.isCompleted = true
                try? context.save()
                NotificationManager.shared.cancelNotification(id: event.id)
                viewModel.fetchEvents()
            } label: {
                Label("Completado",
                      systemImage: "checkmark")
            }
            .tint(.green)
        }
        
    }
}



//#Preview {
//    PetUpcomingTab()
//}

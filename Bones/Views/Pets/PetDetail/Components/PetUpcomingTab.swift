//
//  PetUpcomingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//

import SwiftUI
import SwiftData

struct PetUpcomingEventsTab: View {
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
    
    var body: some View {
    
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName).fontWeight(.semibold)
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
                context.delete(event)            // ahora sí compila
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
//    PetUpcomingEventsTab()
//}

//
//  EventsListView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData

// MARK: - Vista global de eventos
struct EventsListView: View {
    // 1. Contexto para el VM
    let context: ModelContext
    
    // 2. ViewModel
    @StateObject private var vm: EventsListViewModel
    
    // 3. Init para inyectar context → VM
    init(context: ModelContext) {
        self.context = context
        _vm = StateObject(wrappedValue: EventsListViewModel(context: context))
    }
    


    
    // 4. UI
    var body: some View {
        NavigationStack {
            List {
                if vm.sections.isEmpty {
                    ContentUnavailableView("Sin eventos próximos",
                                           systemImage: "calendar")
                } else {
                    ForEach(vm.sections) { section in
                        Section(section.title) {
                            ForEach(section.items, id: \.id) { event in
                                EventRow(event: event, vm: vm)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Eventos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Mostrar completados", isOn: $vm.showPast)
                        // ----------------- Filtro por mascota -----------------
                        Section("Mascota") {
                            Picker("Mascota", selection: $vm.petFilter) {
                                // “Todas” (sin filtro)
                                Label("Todas", systemImage: "pawprint").tag(PetFilter.all)
                                // Generar una opción por cada mascota
                                ForEach(vm.allPets) { pet in
                                    Label(pet.name, systemImage: "pawprint.fill")
                                        .tag(PetFilter(id: pet.id, name: pet.name))
                                }
                            }
                            .pickerStyle(.inline)   // Muestra las filas directamente dentro del menú
                        }
                        
                        // ----------------- Filtro por tipo -----------------
                        Section("Tipo de evento") {
                            Picker("Tipo", selection: $vm.filter) {
                                ForEach(EventTypeFilter.allCases) {
                                    Label($0.rawValue, systemImage: $0.icon).tag($0)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    } label: {
                        // Icono único para los filtros
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }


            .refreshable { vm.fetchAllEvents() }  // pull-to-refresh
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            vm.fetchAllEvents()
        }

    }
    
}

// MARK: - Fila reutilizable
private struct EventRow: View {
    let event: any BasicEvent
    var vm: EventsListViewModel
    
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack(spacing: 12) {
            // ---------- Miniatura ----------
            if let data = event.pet?.photoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "pawprint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    )
            }
            
            // ---------- Texto ----------
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayName)
                    .fontWeight(.semibold)
                
                Text("🐾 \(event.pet?.name ?? "Sin mascota")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(event.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .foregroundStyle(event.isCompleted ? .green : .accentColor)
        }
        // Swipe completar
        .swipeActions(edge: .leading) {
            Button {
                vm.toggleCompleted(event)
            } label: { Label("Completar", systemImage: "checkmark") }
            .tint(.green)
        }
        // Swipe borrar
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                vm.delete(event)
            } label: { Label("Borrar", systemImage: "trash") }
        }
    }
    
    private var icon: String {
        switch event {
        case is Medication:   "pills.fill"
        case is Vaccine:      "syringe"
        case is Deworming:    "ladybug.fill"
        case is Grooming:     "scissors"
        case is WeightEntry:  "scalemass"
        default:              "bell"
        }
    }
}

// MARK: - Helper para icono de filtro
private extension EventTypeFilter {
    var icon: String {
        switch self {
        case .all:         "circle.dashed"
        case .medication:  "pills"
        case .vaccine:     "syringe"
        case .deworming:   "bandage"
        case .grooming:    "scissors"
        case .weight:      "scalemass"
        }
    }
}

enum PastSectionKind: Int, CaseIterable, Hashable {
    case yesterday = 0, lastWeek, lastMonth, earlier
    
    var label: String {
        switch self {
        case .yesterday:  return "Ayer"
        case .lastWeek:   return "Última semana"
        case .lastMonth:  return "Último mes"
        case .earlier:    return "Más antiguos"
        }
    }
}

extension Calendar {
    /// Clasifica una fecha pasada en Ayer, Última semana, Último mes, Más antiguos.
    func pastSectionKind(for date: Date) -> PastSectionKind {
        if isDateInYesterday(date) { return .yesterday }
        
        let now = Date()
        
        // Hace 7 días
        if let weekAgo = self.date(byAdding: .day, value: -7, to: now),
           date >= weekAgo {
            return .lastWeek
        }
        
        // Hace 1 mes
        if let monthAgo = self.date(byAdding: .month, value: -1, to: now),
           date >= monthAgo {
            return .lastMonth
        }
        
        return .earlier
    }
}


//
//#Preview {
//    EventsListsView()
//}



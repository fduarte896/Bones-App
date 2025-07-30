//
//  EventsListViewModel.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import Foundation
import SwiftData
import SwiftUI

enum EventTypeFilter: String, CaseIterable, Identifiable {
    case all        = "Todos"
    case medication = "Medicamentos"
    case vaccine    = "Vacunas"
    case deworming  = "Desparasitación"
    case grooming   = "Grooming"
    case weight     = "Peso"
    
    var id: String { rawValue }
    
    func matches(_ event: any BasicEvent) -> Bool {
        switch self {
        case .all:         return true
        case .medication:  return event is Medication
        case .vaccine:     return event is Vaccine
        case .deworming:   return event is Deworming
        case .grooming:    return event is Grooming
        case .weight:      return event is WeightEntry
        }
    }
}



@MainActor
final class EventsListViewModel: ObservableObject {
    
    // MARK: – Public output
    @Published private(set) var sections: [EventSection] = []
    @Published var filter: EventTypeFilter = .all {
        didSet { buildSections() }
    }
    @Published var petFilter: PetFilter = .all {
        didSet { buildSections() }
    }
    @Published private(set) var allPets: [Pet] = []

    private func fetchPets() {
        allPets = (try? context.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
    
    // EventsListViewModel.swift
    @Published var showPast: Bool = false {
        didSet { buildSections() }
    }

    
    // MARK: – Dependencies
    private let context: ModelContext
    
    // MARK: – Init
    init(context: ModelContext) {
        self.context = context
        fetchAllEvents()
        fetchPets()
    }
    
    // MARK: – Event fetching
    private var allEvents: [any BasicEvent] = []
    
    func fetchAllEvents() {
        // Trae cada tipo – filtraremos después
        var combined: [any BasicEvent] = []
        combined += (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        combined += (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        combined += (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        combined += (try? context.fetch(FetchDescriptor<Grooming>())) ?? []
        combined += (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        
        allEvents = combined
        buildSections()
    }
    
    // MARK: – Build grouped, sorted sections
    private func buildSections() {
        // 1. Filtrado por tipo y (opcional) mascota
        let filtered = allEvents.filter { event in
            filter.matches(event) &&
            (petFilter.id == nil || event.pet?.id == petFilter.id)
        }
        
        // 2. Según el toggle, separamos futuros y pasados
        let futureEvents = filtered
            .filter { $0.date >= Date() && !$0.isCompleted }
            .sorted { $0.date < $1.date }
        
        var tmpSections: [EventSection] = Dictionary(grouping: futureEvents) {
                Calendar.current.sectionKind(for: $0.date)
            }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { EventSection(title: $0.key.label, items: $0.value) }
        
        if showPast {
            let pastEvents = filtered
                .filter { $0.isCompleted || $0.date < Date() }
                .sorted { $0.date > $1.date }              // del más reciente al más antiguo
            
            let pastSections = Dictionary(grouping: pastEvents) {
                    Calendar.current.pastSectionKind(for: $0.date)
                }
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { EventSection(title: $0.key.label, items: $0.value) }
            
            tmpSections.append(contentsOf: pastSections)
        }
        
        sections = tmpSections
    }
    
    // MARK: – Mutating helpers
    func toggleCompleted(_ event: any BasicEvent) {
        event.isCompleted.toggle()
        event.completedAt = event.isCompleted ? Date() : nil
        NotificationManager.shared.cancelNotification(id: event.id)
        try? context.save()
        buildSections()    // o fetchEvents() según el VM
    }

    
    func delete(_ event: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: event.id)
        context.delete(event)
        try? context.save()
        if let done = event.completedAt {
            print("✅ \(event.displayName) completed at \(done.formatted(.dateTime))")
        } else {
            print("↩️ \(event.displayName) marcado como pendiente de nuevo")
        }
        // En EventsListViewModel.delete(_:)
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)

        fetchAllEvents()
    }
}


struct PetFilter: Identifiable, Hashable {
    let id: UUID?
    let name: String
    static let all = PetFilter(id: nil, name: "Todas")
}

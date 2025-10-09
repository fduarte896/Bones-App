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
    case grooming   = "Grooming"
    case weight     = "Peso"
    
    var id: String { rawValue }
    
    func matches(_ event: any BasicEvent) -> Bool {
        switch self {
        case .all:         return true
        case .medication:  return event is Medication
        case .vaccine:     return event is Vaccine
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
    
    // Nueva configuración de “pasados”
    // - Mostrar vencidos (pendientes en el pasado): ON por defecto
    // - Incluir completados: OFF por defecto
    @Published var showOverdue: Bool = true {
        didSet { buildSections() }
    }
    @Published var includeCompletedPast: Bool = false {
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
        
        let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        combined.append(contentsOf: meds.map { $0 as any BasicEvent })
        
        let vacs = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        combined.append(contentsOf: vacs.map { $0 as any BasicEvent })
        
        let dews = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        combined.append(contentsOf: dews.map { $0 as any BasicEvent })
        
        let grooms = (try? context.fetch(FetchDescriptor<Grooming>())) ?? []
        combined.append(contentsOf: grooms.map { $0 as any BasicEvent })
        
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        combined.append(contentsOf: weights.map { $0 as any BasicEvent })
        
        allEvents = combined
        buildSections()
    }
    
    // MARK: – Build grouped, sorted sections
    private func buildSections() {
        let now = Date()
        let cal = Calendar.current
        
        // 1. Filtrado por tipo y (opcional) mascota
        let filtered = allEvents.filter { event in
            filter.matches(event) &&
            (petFilter.id == nil || event.pet?.id == petFilter.id)
        }
        
        // 2. “Hoy” debe incluir todos los pendientes de hoy (aunque ya hayan pasado) + futuros > ahora
        let todayPending = filtered.filter { !$0.isCompleted && cal.isDateInToday($0.date) }
        let futureBeyondToday = filtered.filter { !$0.isCompleted && $0.date > now && !cal.isDateInToday($0.date) }
        let futureEvents = (todayPending + futureBeyondToday).sorted { $0.date < $1.date }
        
        var tmpSections: [EventSection] = Dictionary(grouping: futureEvents) {
                Calendar.current.sectionKind(for: $0.date)
            }
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { EventSection(title: $0.key.label, items: $0.value) }
        
        // 3. Vencidos (pendientes en el pasado) – opcional, EXCLUYENDO los de hoy
        if showOverdue {
            let overdueEvents = filtered
                .filter { !$0.isCompleted && $0.date < now && !cal.isDateInToday($0.date) }
                .sorted { $0.date > $1.date } // del más reciente al más antiguo
            if !overdueEvents.isEmpty {
                let overdueSections = Dictionary(grouping: overdueEvents) {
                        Calendar.current.pastSectionKind(for: $0.date)
                    }
                    .sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { EventSection(title: $0.key.label, items: $0.value) }
                tmpSections.append(contentsOf: overdueSections)
            }
        }
        
        // 4. Completados (solo si el usuario los quiere ver)
        if includeCompletedPast {
            let completedEvents = filtered
                .filter { $0.isCompleted }
                .sorted { $0.date > $1.date }
            if !completedEvents.isEmpty {
                let completedSections = Dictionary(grouping: completedEvents) {
                        Calendar.current.pastSectionKind(for: $0.date)
                    }
                    .sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { EventSection(title: $0.key.label, items: $0.value) }
                tmpSections.append(contentsOf: completedSections)
            }
        }
        
        sections = tmpSections
    }
    
    // MARK: – Mutating helpers
    func toggleCompleted(_ event: any BasicEvent) {
        event.isCompleted.toggle()
        event.completedAt = event.isCompleted ? Date() : nil
        NotificationManager.shared.cancelNotification(id: event.id)
        try? context.save()
        buildSections()
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
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        fetchAllEvents()
    }
}

struct PetFilter: Identifiable, Hashable {
    let id: UUID?
    let name: String
    static let all = PetFilter(id: nil, name: "Todas")
}

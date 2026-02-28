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
    @Published var searchQuery: String = "" {
        didSet { buildSections() }
    }

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
            (petFilter.id == nil || event.pet?.id == petFilter.id) &&
            matchesSearch(event: event, query: searchQuery)
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

    // MARK: - Search
    private func matchesSearch(event: any BasicEvent, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let needle = trimmed.lowercased()

        // Texto
        let textFields: [String] = [
            event.displayName,
            event.displayType,
            event.notes ?? "",
            event.pet?.name ?? ""
        ]
        if textFields.contains(where: { $0.lowercased().contains(needle) }) {
            return true
        }

        // Fecha: intenta parsear y comparar por día
        if let qDate = parseDate(from: trimmed) {
            return Calendar.current.isDate(event.date, inSameDayAs: qDate)
        }

        // Fecha: fallback por coincidencia en strings formateados
        let dateStrings = formattedDateStrings(for: event.date)
        return dateStrings.contains(where: { $0.lowercased().contains(needle) })
    }

    private func parseDate(from input: String) -> Date? {
        let formats = [
            "d/M/yyyy",
            "d/M/yy",
            "dd/MM/yyyy",
            "dd/MM/yy",
            "d/M",
            "dd/MM"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        for f in formats {
            formatter.dateFormat = f
            if let date = formatter.date(from: input) {
                return date
            }
        }
        return nil
    }

    private func formattedDateStrings(for date: Date) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        let formats = [
            "d/M/yyyy",
            "dd/MM/yyyy",
            "d/M",
            "dd/MM",
            "d MMM",
            "d MMMM",
            "MMM d",
            "MMMM d"
        ]
        return formats.map {
            formatter.dateFormat = $0
            return formatter.string(from: date)
        }
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

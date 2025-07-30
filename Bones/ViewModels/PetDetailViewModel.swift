//
//  PetDetailViewModel.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - ViewModel adaptado
@MainActor
final class PetDetailViewModel: ObservableObject {
    @Published var upcomingEvents: [any BasicEvent] = []
    
    private var context: ModelContext?
    private let petID: UUID
    
    // Se crea solo con el id – el context llega después
    init(petID: UUID) { self.petID = petID }
    
    /// Llamar una vez que la vista ya tenga `modelContext` disponible.
    func inject(context: ModelContext) {
        guard self.context == nil else { return } // evitar doble inyección
        self.context = context
        fetchEvents()
    }
    
    
    private func fetch<T: BasicEvent & PersistentModel>(
        _ type: T.Type,
        in context: ModelContext
    ) -> [T] {
        let predicate = #Predicate<T> { $0.pet?.id == petID }
        let desc = FetchDescriptor<T>(predicate: predicate)
        return (try? context.fetch(desc)) ?? []
    }
    
    // 1️⃣  Estructura auxiliar
    struct EventSection: Identifiable {
        let id = UUID()
        let title: String
        let items: [any BasicEvent]
    }

    // 2️⃣  Propiedad publicada
    @Published var groupedUpcomingEvents: [EventSection] = []

    // 3️⃣  Actualiza fetchEvents()
    func fetchEvents() {
        guard let context else { return }

        var all: [any BasicEvent] = []
        all.append(contentsOf: fetch(Medication.self,  in: context))
        all.append(contentsOf: fetch(Vaccine.self,     in: context))
        all.append(contentsOf: fetch(Deworming.self,   in: context))
        all.append(contentsOf: fetch(Grooming.self,    in: context))
        all.append(contentsOf: fetch(WeightEntry.self, in: context))

        let upcoming = all
            .filter { $0.date >= Date() && !$0.isCompleted }
            .sorted { $0.date < $1.date }

        let dict = Dictionary(grouping: upcoming) { event in
            Calendar.current.sectionKind(for: event.date)
        }

        groupedUpcomingEvents = dict
            .sorted { $0.key.rawValue < $1.key.rawValue }      // orden lógico
            .map { EventSection(title: $0.key.label, items: $0.value) }

        
    }

    // MARK: - Pesos por mascota
    var weights: [WeightEntry] {
        guard let context else { return [] }
        let all = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        return all
            .filter { $0.pet?.id == petID }
            .sorted { $0.date > $1.date }          // más reciente primero
    }

    // Peso actual (última medición)
    var currentWeight: WeightEntry? { weights.first }

    // Variación vs. anterior
    var deltaDescription: String {
        guard weights.count >= 2 else { return "–" }
        let diff = weights.first!.weightKg - weights[1].weightKg
        return diff == 0 ? "0 kg"
             : String(format: "%+.1f kg", diff)
    }

    func toggleCompleted(_ event: any BasicEvent) {
        guard let context else { return }           // ⬅️ desenvuelve
        
        event.isCompleted.toggle()
        event.completedAt = event.isCompleted ? Date() : nil
        NotificationManager.shared.cancelNotification(id: event.id)
        try? context.save()                         // ya no marca error
        
        if let done = event.completedAt {
            print("✅ \(event.displayName) completed at \(done.formatted(.dateTime))")
        } else {
            print("↩️ \(event.displayName) marcado como pendiente de nuevo")
        }
        fetchEvents()
    }



}

extension Calendar {
    /// Devuelve la categoría de sección para una fecha futura.
    func sectionKind(for date: Date) -> EventSectionKind {
        if isDateInToday(date) {
            return .today
        } else if isDateInTomorrow(date) {
            return .tomorrow
        }
        
        // Semana actual
        if isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return .thisWeek
        }
        
        // Próxima semana
        if let nextWeek = self.date(byAdding: .weekOfYear, value: 1, to: Date()),
           isDate(date, equalTo: nextWeek, toGranularity: .weekOfYear) {
            return .nextWeek
        }
        
        return .later
    }
}






// MARK: - Filtering helpers
extension PetDetailViewModel {
    
    /// Medicamentos ordenados por fecha (más recientes arriba).
    // MARK: - Medicamentos por mascota
    var medications: [Medication] {
        guard let context else { return [] }
        
        // 1. Trae TODO de Medication (rápido: pocos objetos)
        let all = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        
        // 2. Filtra por mascota
        let filtered = all.filter { $0.pet?.id == petID }
        
        // 3. Ordena (más reciente arriba)
        return filtered.sorted { $0.date > $1.date }
    }
    
    // MARK: - Vacunas por mascota
    var vaccines: [Vaccine] {
        guard let context else { return [] }
        
        let all = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let filtered = all.filter { $0.pet?.id == petID }
        
        return filtered.sorted { $0.date > $1.date }   // más reciente arriba
    }


    // MARK: - Grooming por mascota
    var groomings: [Grooming] {
        guard let context else { return [] }
        
        let all = (try? context.fetch(FetchDescriptor<Grooming>())) ?? []
        let filtered = all.filter { $0.pet?.id == petID }
        
        // Orden: próximos primero (fecha futura) y, si quieres,
        // completados al final o con otro criterio
        return filtered.sorted { $0.date > $1.date }
    }
    
    // MARK: - Desparasitación por mascota
    var dewormings: [Deworming] {
        guard let context else { return [] }
        
        let all = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let filtered = all.filter { $0.pet?.id == petID }
        
        return filtered.sorted { $0.date > $1.date }   // próximo primero
    }


}

enum EventSectionKind: Int, CaseIterable, Hashable {
    case today = 0
    case tomorrow
    case thisWeek
    case nextWeek
    case later
    
    var label: String {
        switch self {
        case .today:     return "Hoy"
        case .tomorrow:  return "Mañana"
        case .thisWeek:  return "Esta semana"
        case .nextWeek:  return "Próxima semana"
        case .later:     return "Más adelante"
        }
    }
}

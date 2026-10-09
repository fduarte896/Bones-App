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
    
    // 2️⃣  Propiedad publicada
    @Published var groupedUpcomingEvents: [EventSection] = []

    // 3️⃣  Actualiza fetchEvents() con predicados concretos por tipo
    func fetchEvents() {
        guard let context else { return }

        let all = context.fetchAllEvents().filter { $0.pet?.id == petID }

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
        return context.fetchAll(WeightEntry.self)
            .filter { $0.pet?.id == petID }
            .sorted { $0.date > $1.date }
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

    var weightTrend: WeightTrend {
        guard weights.count >= 2 else { return .flat }
        let diff = weights.first!.weightKg - weights[1].weightKg
        if diff > 0 { return .up }
        if diff < 0 { return .down }
        return .flat
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

// MARK: - Filtering helpers
extension PetDetailViewModel {

    // MARK: - Vacunas por mascota
    var vaccines: [Vaccine] {
        guard let context else { return [] }
        return context.fetchAll(Vaccine.self)
            .filter { $0.pet?.id == petID }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Desparasitación por mascota
    var dewormings: [Deworming] {
        guard let context else { return [] }
        return context.fetchAll(Deworming.self)
            .filter { $0.pet?.id == petID }
            .sorted { $0.date > $1.date }
    }
}

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

// MARK: - Consolidación de vacunas (Fase 1)
extension PetDetailViewModel {
    enum VaccineSeriesStatus: Equatable {
        case notStarted
        case inProgress(current: Int, total: Int?)
        case completed
        case booster(nextDate: Date?)
    }
    
    struct VaccineSeriesSummary: Identifiable {
        let id = UUID()
        let baseName: String
        let items: [Vaccine]                 // todas las dosis de la serie, ordenadas por fecha asc
        let lastCompleted: Vaccine?          // última marcada como completada
        let nextPending: Vaccine?            // próxima pendiente (futura) si existe
        let status: VaccineSeriesStatus
        let overdueDays: Int?                // si hay pendientes vencidas (en pasado, no completadas)
    }
    
    // Todas las vacunas de esta mascota, ya existe computed 'vaccines' más abajo.
    // Agrupación y estado por serie:
    var vaccineSeriesSummaries: [VaccineSeriesSummary] {
        // Partimos de 'vaccines' ya filtradas por mascota y ordenadas ascendente
        let all = vaccines
        let groups = Dictionary(grouping: all) { DoseSeries.splitDoseBase(from: $0.vaccineName) }
        let now = Date()
        
        func daysBetween(_ from: Date, _ to: Date) -> Int {
            let comps = Calendar.current.dateComponents([.day], from: from, to: to)
            return abs(comps.day ?? 0)
        }
        
        return groups.keys.sorted().compactMap { base in
            let items = (groups[base] ?? []).sorted { $0.date < $1.date }
            let lastCompleted = items.filter { $0.isCompleted }.max(by: { $0.date < $1.date })
            let nextPendingFuture = items
                .filter { !$0.isCompleted && $0.date >= now }
                .min(by: { $0.date < $1.date })
            
            // Pendientes vencidas (en pasado sin completar)
            let pendingPast = items
                .filter { !$0.isCompleted && $0.date < now }
                .sorted { $0.date < $1.date }
            let overdueDays: Int? = {
                guard let lastPast = pendingPast.last else { return nil }
                return daysBetween(lastPast.date, now)
            }()
            
            // Cálculo de X/Y esperado e índice actual
            let totals = items.compactMap { DoseSeries.parseDoseNumbers(from: $0.vaccineName).total }
            let totalExpected = totals.max()         // si hay etiquetas X/Y, usamos el mayor Y visto
            // Para "current", contamos completadas con número de dosis si existe; si no, usamos cantidad de completadas
            let completedCountByLabel = items
                .filter { $0.isCompleted }
                .compactMap { DoseSeries.parseDoseNumbers(from: $0.vaccineName).current }
                .max() ?? 0
            let completedCountFallback = items.filter { $0.isCompleted }.count
            let completedCount = max(completedCountByLabel, completedCountFallback)
            
            // Estado de la serie
            let status: VaccineSeriesStatus = {
                if let total = totalExpected, completedCount >= total {
                    return .completed
                }
                if let next = nextPendingFuture {
                    if DoseSeries.isBooster(next, among: items) {
                        return .booster(nextDate: next.date)
                    }
                    return .inProgress(current: max(1, completedCount + 1), total: totalExpected)
                }
                // Sin próxima programada:
                if completedCount == 0 {
                    return .notStarted
                }
                if let total = totalExpected, completedCount < total {
                    // En progreso pero sin próxima programada explícita
                    return .inProgress(current: max(1, completedCount + 1), total: total)
                }
                // Podría ser un esquema sin X/Y ya completado o a la espera de refuerzo manual
                return .completed
            }()
            
            return VaccineSeriesSummary(
                baseName: base,
                items: items,
                lastCompleted: lastCompleted,
                nextPending: nextPendingFuture,
                status: status,
                overdueDays: overdueDays
            )
        }
    }
    
    // Próximas por serie: como máximo 1 por base (la próxima pendiente futura)
    var upcomingVaccinesBySeries: [Vaccine] {
        vaccineSeriesSummaries
            .compactMap { $0.nextPending }
            .sorted { $0.date < $1.date }
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

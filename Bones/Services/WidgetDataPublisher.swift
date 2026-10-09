import Foundation
import SwiftData
import WidgetKit

/// Copia las próximas fechas al contenedor compartido para que el widget las lea.
@MainActor
enum WidgetDataPublisher {
    static func update(using context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let pets = (try? context.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let today = calendar.startOfDay(for: now)

        var eventsByPetID: [String: [WidgetEventSummary]] = [:]
        for pet in pets {
            let vaccines = pet.vaccines
                .filter { !$0.isCompleted && $0.date >= today }
                .map { WidgetEventSummary(id: $0.id.uuidString, title: $0.displayName, type: "Vacuna", date: $0.date) }
            let dewormings = pet.dewormings
                .filter { !$0.isCompleted && $0.date >= today }
                .map {
                    WidgetEventSummary(id: $0.id.uuidString,
                                       title: $0.productName.nilIfBlank ?? $0.kind.longName,
                                       type: "Desparasitación",
                                       date: $0.date)
                }
            eventsByPetID[pet.id.uuidString] = Array(
                (vaccines + dewormings).sorted { $0.date < $1.date }.prefix(WidgetConstants.maxEventsPerPet)
            )
        }

        WidgetStore.save(WidgetPayload(
            pets: pets.map { WidgetPetSummary(id: $0.id.uuidString, name: $0.name) },
            eventsByPetID: eventsByPetID,
            generatedAt: now
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }
}

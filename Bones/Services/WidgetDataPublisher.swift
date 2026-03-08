//
//  WidgetDataPublisher.swift
//  Bones
//

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WidgetDataPublisher: ObservableObject {
    static let shared = WidgetDataPublisher()
    private init() {}

    func update(using context: ModelContext) {
        let now = Date()

        func fetch<T: PersistentModel>(
            _ type: T.Type,
            predicate: Predicate<T>,
            sort: SortDescriptor<T>
        ) -> [T] {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            descriptor.sortBy = [sort]
            return (try? context.fetch(descriptor)) ?? []
        }

        let pets = (try? context.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var eventsByPetID: [String: [WidgetEventSummary]] = [:]

        for pet in pets {
            let petID = pet.id
            let meds: [Medication] = fetch(Medication.self,
                                           predicate: #Predicate { !$0.isCompleted && $0.date >= now && $0.pet?.id == petID },
                                           sort: .init(\.date, order: .forward))
            let vacs: [Vaccine] = fetch(Vaccine.self,
                                        predicate: #Predicate { !$0.isCompleted && $0.date >= now && $0.pet?.id == petID },
                                        sort: .init(\.date, order: .forward))
            let dews: [Deworming] = fetch(Deworming.self,
                                          predicate: #Predicate { !$0.isCompleted && $0.date >= now && $0.pet?.id == petID },
                                          sort: .init(\.date, order: .forward))
            let grooms: [Grooming] = fetch(Grooming.self,
                                           predicate: #Predicate { !$0.isCompleted && $0.date >= now && $0.pet?.id == petID },
                                           sort: .init(\.date, order: .forward))

            var combined: [any BasicEvent] = []
            combined.append(contentsOf: meds.map { $0 as any BasicEvent })
            combined.append(contentsOf: vacs.map { $0 as any BasicEvent })
            combined.append(contentsOf: dews.map { $0 as any BasicEvent })
            combined.append(contentsOf: grooms.map { $0 as any BasicEvent })

            let sorted = combined.sorted { $0.date < $1.date }
            let summaries = sorted.prefix(WidgetConstants.maxEventsPerPet).map { event in
                WidgetEventSummary(id: event.id.uuidString,
                                   title: event.displayName,
                                   type: event.displayType,
                                   date: event.date)
            }
            eventsByPetID[pet.id.uuidString] = summaries
        }

        let payload = WidgetPayload(
            pets: pets.map { WidgetPetSummary(id: $0.id.uuidString, name: $0.name) },
            eventsByPetID: eventsByPetID,
            generatedAt: now
        )
        WidgetStore.save(payload)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// Sync helper for SwiftUI
import SwiftUI

struct WidgetDataSyncer: ViewModifier {
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .onAppear { WidgetDataPublisher.shared.update(using: context) }
            .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
                WidgetDataPublisher.shared.update(using: context)
            }
    }
}

extension View {
    func syncWidgetData() -> some View {
        modifier(WidgetDataSyncer())
    }
}

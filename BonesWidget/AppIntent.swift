//
//  AppIntent.swift
//  BonesWidget
//
//  Created by Felipe Duarte on 8/03/26.
//

import WidgetKit
import AppIntents

enum EventTypeIntent: String, AppEnum {
    case all
    case medication
    case vaccine
    case deworming
    case grooming
    case weight

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo de evento"
    static var caseDisplayRepresentations: [EventTypeIntent: DisplayRepresentation] = [
        .all: "Todos",
        .medication: "Medicamentos",
        .vaccine: "Vacunas",
        .deworming: "Desparasitación",
        .grooming: "Peluquería",
        .weight: "Peso"
    ]
}

struct PetSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Mascota"
    static var description = IntentDescription("Selecciona la mascota y el tipo de evento a mostrar.")

    @Parameter(title: "Mascota")
    var pet: PetEntity?

    @Parameter(title: "Tipo de evento", default: .all)
    var eventType: EventTypeIntent
}

struct PetEntity: AppEntity, Hashable, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mascota"
    static var defaultQuery = PetQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct PetQuery: EntityQuery {
    func entities(for identifiers: [PetEntity.ID]) async throws -> [PetEntity] {
        let payload = WidgetStore.load()
        let pets = payload?.pets ?? []
        return pets
            .filter { identifiers.contains($0.id) }
            .map { PetEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [PetEntity] {
        let payload = WidgetStore.load()
        return (payload?.pets ?? []).map { PetEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> PetEntity? {
        let payload = WidgetStore.load()
        guard let first = payload?.pets.first else { return nil }
        return PetEntity(id: first.id, name: first.name)
    }
}

//
//  AppIntent.swift
//  BonesWidget
//
//  Created by Felipe Duarte on 8/03/26.
//

import WidgetKit
import AppIntents

struct PetSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Mascota"
    static var description = IntentDescription("Selecciona la mascota a mostrar en el widget.")

    @Parameter(title: "Mascota")
    var pet: PetEntity?
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

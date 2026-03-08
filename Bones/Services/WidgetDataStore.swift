//
//  WidgetDataStore.swift
//  Bones
//
//  Shared payload for widget + app sync.
//

import Foundation

enum WidgetConstants {
    static let appGroupID = "group.Felipeduarte.bones"
    static let payloadKey = "widget.payload.v1"
    static let maxEventsPerPet = 5
}

struct WidgetPetSummary: Codable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct WidgetEventSummary: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let type: String
    let date: Date
}

struct WidgetPayload: Codable, Hashable {
    let pets: [WidgetPetSummary]
    let eventsByPetID: [String: [WidgetEventSummary]]
    let generatedAt: Date
}

enum WidgetStore {
    static func load() -> WidgetPayload? {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupID),
              let data = defaults.data(forKey: WidgetConstants.payloadKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetPayload.self, from: data)
    }

    static func save(_ payload: WidgetPayload) {
        guard let defaults = UserDefaults(suiteName: WidgetConstants.appGroupID) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: WidgetConstants.payloadKey)
    }
}

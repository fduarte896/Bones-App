import Testing
import Foundation
@testable import Bones

@Suite(.tags(.widgets))
struct WidgetDataStoreTests {

    @Test func widgetPayload_encodeDecode_roundtrip() throws {
        let pet = WidgetPetSummary(id: "pet-1", name: "Luna")
        let event = WidgetEventSummary(id: "ev-1", title: "Vacuna Rabia", type: "Vacuna", date: makeDate())
        let payload = WidgetPayload(pets: [pet], eventsByPetID: ["pet-1": [event]], generatedAt: makeDate())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetPayload.self, from: data)

        #expect(decoded.pets.count == 1)
        #expect(decoded.pets.first?.name == "Luna")
        let events = try #require(decoded.eventsByPetID["pet-1"])
        #expect(events.count == 1)
        #expect(events.first?.title == "Vacuna Rabia")
    }

    @Test func widgetPayload_emptyPets_encodeDecode() throws {
        let payload = WidgetPayload(pets: [], eventsByPetID: [:], generatedAt: makeDate())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetPayload.self, from: data)

        #expect(decoded.pets.isEmpty)
        #expect(decoded.eventsByPetID.isEmpty)
    }

    @Test func widgetPetSummary_identifiable() {
        let pet = WidgetPetSummary(id: "abc-123", name: "Max")
        #expect(pet.id == "abc-123")
    }

    @Test func widgetEventSummary_datePreserved() throws {
        let date = makeDate(year: 2026, month: 3, day: 15, hour: 14, minute: 30)
        let event = WidgetEventSummary(id: "e1", title: "Test", type: "Medication", date: date)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetEventSummary.self, from: data)

        // ISO8601 has second precision, so compare within 1 second
        #expect(abs(decoded.date.timeIntervalSince(date)) < 1)
    }

    @Test func widgetPayload_hashable() {
        let date = makeDate()
        let p1 = WidgetPayload(pets: [], eventsByPetID: [:], generatedAt: date)
        let p2 = WidgetPayload(pets: [], eventsByPetID: [:], generatedAt: date)
        #expect(p1.hashValue == p2.hashValue)
    }
}

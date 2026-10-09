import Foundation
import SwiftData

/// Datos de ejemplo para las vistas previas de Xcode.
@MainActor
enum PreviewData {
    static func container(seeded: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: Pet.self, Vaccine.self, Deworming.self, WeightEntry.self,
            configurations: configuration
        ) else {
            fatalError("No se pudo crear el contenedor de vista previa")
        }
        if seeded { seed(container.mainContext) }
        return container
    }

    static func firstPet(in container: ModelContainer) -> Pet {
        let pets = (try? container.mainContext.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.name)]))) ?? []
        return pets.first ?? Pet(name: "Marcos")
    }

    private static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: .now) ?? .now
        }

        let marcos = Pet(name: "Marcos", species: .perro, breed: "Pastor australiano",
                         birthDate: day(-4 * 365), sex: .male)
        let luna = Pet(name: "Luna", species: .gato, birthDate: day(-200), sex: .female)
        context.insert(marcos)
        context.insert(luna)

        let log = HealthLog(context: context)
        let quarterly = RepeatRule(value: 3, unit: .months)

        _ = try? log.saveDeworming(
            RecordDraft(kind: .deworming, name: "Drontal Plus", date: day(-150), repeatRule: quarterly), for: marcos)
        _ = try? log.saveDeworming(
            RecordDraft(kind: .deworming, name: "Drontal Plus", date: day(-62), repeatRule: quarterly), for: marcos)
        _ = try? log.saveDeworming(
            RecordDraft(kind: .deworming, name: "Bravecto", dewormingKind: .external, date: day(-95), repeatRule: quarterly),
            for: marcos)
        _ = try? log.saveVaccine(
            RecordDraft(kind: .vaccine, name: "Antirrábica", date: day(-345), repeatRule: .yearly), for: marcos)
        _ = try? log.saveVaccine(
            RecordDraft(kind: .vaccine, name: "Polivalente", date: day(-60), repeatRule: .yearly), for: marcos)
        for (offset, kg) in [(-120, 8.2), (-90, 8.7), (-45, 9.1), (-3, 9.4)] {
            _ = try? log.saveWeight(RecordDraft(kind: .weight, date: day(offset), weightKg: kg), for: marcos)
        }
    }
}

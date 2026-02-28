import Foundation
import SwiftData

@MainActor
enum DewormingSeeder {
    // UserDefaults key to ensure we only seed once per install
    private static let didSeedKey = "didSeedDewormingDemo"

    /// Seeds demo Deworming data globally on first run if the store has none yet.
    /// - Parameter context: A valid SwiftData ModelContext
    static func seedIfNeeded(using context: ModelContext) {
        // Already seeded in this install?
        if UserDefaults.standard.bool(forKey: didSeedKey) { return }

        // If there is any Deworming already, mark as seeded and exit
        let existing: [Deworming]
        do {
            existing = try context.fetch(FetchDescriptor<Deworming>())
        } catch {
            // If fetching fails, don't attempt to seed to avoid duplications
            return
        }
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: didSeedKey)
            return
        }

        // Attempt to pick any existing Pet to attach demo data to.
        // If there is no Pet yet, we can optionally create a demo Pet.
        // Here we create a demo pet if none exists to ensure the demo data is visible.
        let petFetch = FetchDescriptor<Pet>(predicate: nil)
        let demoPet: Pet
        if let somePet = try? context.fetch(petFetch).first, let pet = somePet {
            demoPet = pet
        } else {
            // Create a demo pet
            demoPet = Pet(
                name: "Loki",
                species: .perro,
                breed: "Husky",
                birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
                sex: .male,
                color: "White"
            )
            context.insert(demoPet)
        }

        let cal = Calendar.current
        let now = Date()

        // Serie A: Drontal Plus — hoy + 15 días (2/2), luego refuerzo a 3 meses
        let seriesA = UUID()
        let a1 = Deworming(date: now,
                           pet: demoPet,
                           notes: "Drontal Plus (dosis 1/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        a1.isCompleted = true
        let a2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                           pet: demoPet,
                           notes: "Drontal Plus (dosis 2/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesA)
        let aBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                 pet: demoPet,
                                 notes: "Drontal Plus",
                                 prescriptionImageData: nil,
                                 seriesID: seriesA)

        // Serie B: Endogard — 2/2 con una vencida y una futura, y un refuerzo a 3 meses
        let seriesB = UUID()
        let b1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!,
                           pet: demoPet,
                           notes: "Endogard (dosis 1/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        let b2 = Deworming(date: cal.date(byAdding: .day, value: 5, to: now)!,
                           pet: demoPet,
                           notes: "Endogard (dosis 2/2)",
                           prescriptionImageData: nil,
                           seriesID: seriesB)
        let bBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                 pet: demoPet,
                                 notes: "Endogard",
                                 prescriptionImageData: nil,
                                 seriesID: seriesB)

        // Serie C: Panacur — 3 días seguidos y repetir el ciclo a los 14 días
        let seriesC = UUID()
        let c1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                           pet: demoPet,
                           notes: "Panacur (dosis 1/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        c1.isCompleted = true
        let c2 = Deworming(date: now,
                           pet: demoPet,
                           notes: "Panacur (dosis 2/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        let c3 = Deworming(date: cal.date(byAdding: .day, value: 1, to: now)!,
                           pet: demoPet,
                           notes: "Panacur (dosis 3/3)",
                           prescriptionImageData: nil,
                           seriesID: seriesC)
        let cR1 = Deworming(date: cal.date(byAdding: .day, value: 14, to: now)!,
                            pet: demoPet,
                            notes: "Panacur (dosis 1/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)
        let cR2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: demoPet,
                            notes: "Panacur (dosis 2/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)
        let cR3 = Deworming(date: cal.date(byAdding: .day, value: 16, to: now)!,
                            pet: demoPet,
                            notes: "Panacur (dosis 3/3)",
                            prescriptionImageData: nil,
                            seriesID: seriesC)

        [a1, a2, aBooster,
         b1, b2, bBooster,
         c1, c2, c3, cR1, cR2, cR3].forEach { context.insert($0) }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        } catch {
            // If saving fails, do not mark as seeded so we can retry next launch
        }
    }
}

import Testing
import Foundation
import SwiftData
@testable import Bones

// MARK: - Tags

extension Tag {
    @Tag static var models: Self
    @Tag static var viewModels: Self
    @Tag static var parsing: Self
    @Tag static var scheduling: Self
    @Tag static var widgets: Self
}

// MARK: - SwiftData Factory

@MainActor
func makeContext() throws -> ModelContext {
    let schema = Schema([
        Pet.self,
        Medication.self,
        Vaccine.self,
        Deworming.self,
        Grooming.self,
        WeightEntry.self
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

// MARK: - Date Factory

/// Creates a deterministic date in UTC to avoid timezone-dependent test failures.
func makeDate(
    year: Int = 2026, month: Int = 6, day: Int = 15,
    hour: Int = 10, minute: Int = 0
) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal.date(from: DateComponents(
        year: year, month: month, day: day,
        hour: hour, minute: minute
    )) ?? Date(timeIntervalSince1970: 0)
}

// MARK: - Pet Factory

@MainActor
@discardableResult
func makePet(in context: ModelContext, name: String = "Luna") -> Pet {
    let pet = Pet(name: name)
    context.insert(pet)
    try! context.save()
    return pet
}

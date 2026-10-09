import Testing
import Foundation
import SwiftData
@testable import Bones

extension Tag {
    @Tag static var models: Self
    @Tag static var summary: Self
    @Tag static var logging: Self
    @Tag static var formatting: Self
    @Tag static var migration: Self
    @Tag static var reminders: Self
    @Tag static var widgets: Self
}

/// Calendario fijo para que los tests no dependan de la zona horaria de la máquina.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// "Hoy" en los tests: 15 de junio de 2026 a mediodía.
let testNow = makeDate()

@MainActor
func makeContext() throws -> ModelContext {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Pet.self, Vaccine.self, Deworming.self, WeightEntry.self,
        configurations: configuration
    )
    return ModelContext(container)
}

func makeDate(year: Int = 2026, month: Int = 6, day: Int = 15, hour: Int = 12, minute: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
        ?? Date(timeIntervalSince1970: 0)
}

/// Una fecha a `offset` días de `testNow`.
func day(_ offset: Int) -> Date {
    testCalendar.date(byAdding: .day, value: offset, to: testNow) ?? testNow
}

@MainActor
@discardableResult
func makePet(in context: ModelContext, name: String = "Luna") throws -> Pet {
    let pet = Pet(name: name)
    context.insert(pet)
    try context.save()
    return pet
}

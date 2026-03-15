import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.viewModels))
struct CalendarEventsViewModelTests {
    let context: ModelContext
    let pet: Pet
    let vm: CalendarEventsViewModel

    init() throws {
        context = try makeContext()
        pet = makePet(in: context, name: "Luna")
        vm = CalendarEventsViewModel()
        vm.inject(context: context)
    }

    @Test func init_noEvents_emptyEventsByDay() {
        #expect(vm.eventsByDay.isEmpty)
    }

    @Test func fetchAll_groupsByDay() throws {
        let day1 = makeDate(year: 2026, month: 6, day: 10)
        let day2 = makeDate(year: 2026, month: 6, day: 15)
        context.insert(Medication(date: day1, pet: pet, name: "Med1", dosage: "10mg", frequency: "8h"))
        context.insert(Medication(date: day2, pet: pet, name: "Med2", dosage: "10mg", frequency: "8h"))
        try context.save()
        vm.fetchAll()

        #expect(vm.eventsByDay.count == 2)
    }

    @Test func fetchAll_sameDay_groupedTogether() throws {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 10)
        let date2 = makeDate(year: 2026, month: 6, day: 15, hour: 14)
        context.insert(Medication(date: date, pet: pet, name: "Med1", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: date2, pet: pet, vaccineName: "Rabia"))
        try context.save()
        vm.fetchAll()

        let dayKey = Calendar.current.startOfDay(for: date)
        let events = vm.eventsByDay[dayKey] ?? []
        #expect(events.count == 2)
    }

    @Test func eventsOnDay_returnsCorrectEvents() throws {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 10)
        context.insert(Medication(date: date, pet: pet, name: "Med1", dosage: "10mg", frequency: "8h"))
        try context.save()
        vm.fetchAll()

        let events = vm.events(on: date)
        #expect(events.count == 1)
    }

    @Test func eventsOnDay_noneForEmptyDay() {
        let randomDay = makeDate(year: 2030, month: 1, day: 1)
        let events = vm.events(on: randomDay)
        #expect(events.isEmpty)
    }

    @Test func fetchAll_allEventTypes() throws {
        let date = makeDate(year: 2026, month: 6, day: 15)
        context.insert(Medication(date: date, pet: pet, name: "Med", dosage: "10mg", frequency: "8h"))
        context.insert(Vaccine(date: date, pet: pet, vaccineName: "Rabia"))
        context.insert(Deworming(date: date, pet: pet))
        context.insert(Grooming(date: date, pet: pet))
        context.insert(WeightEntry(date: date, pet: pet, weightKg: 10.0))
        try context.save()
        vm.fetchAll()

        let dayKey = Calendar.current.startOfDay(for: date)
        let events = vm.eventsByDay[dayKey] ?? []
        #expect(events.count == 5, "All 5 event types should be fetched")
    }
}

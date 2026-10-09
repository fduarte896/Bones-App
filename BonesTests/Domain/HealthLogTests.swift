import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.logging))
struct HealthLogTests {
    let context: ModelContext
    let pet: Pet
    let log: HealthLog

    private let quarterly = RepeatRule(value: 3, unit: .months)

    init() throws {
        context = try makeContext()
        pet = try makePet(in: context)
        log = HealthLog(context: context, calendar: testCalendar)
    }

    private func dewormingDraft(_ product: String = "Drontal Plus", kind: DewormingKind = .internal,
                                at offset: Int = 0, repeatRule: RepeatRule? = nil) -> RecordDraft {
        RecordDraft(kind: .deworming, name: product, dewormingKind: kind, date: day(offset), repeatRule: repeatRule)
    }

    private func vaccineDraft(_ name: String = "Antirrábica", at offset: Int = 0,
                              repeatRule: RepeatRule? = nil) -> RecordDraft {
        RecordDraft(kind: .vaccine, name: name, date: day(offset), repeatRule: repeatRule)
    }

    private var pending: [Deworming] { pet.dewormings.filter { !$0.isCompleted } }
    private var applied: [Deworming] { pet.dewormings.filter(\.isCompleted) }

    // MARK: Registrar

    @Test func loggingTodayIsStoredAsApplied() throws {
        let record = try log.saveDeworming(dewormingDraft(), for: pet, now: testNow)

        #expect(record.isCompleted, "Lo que se registra con fecha de hoy ya está aplicado")
        #expect(record.completedAt == testNow)
        #expect(record.productName == "Drontal Plus")
        #expect(record.kind == .internal)
        #expect(pending.isEmpty)
    }

    @Test func loggingAPastDateIsStoredAsApplied() throws {
        let record = try log.saveVaccine(vaccineDraft(at: -40), for: pet, now: testNow)
        #expect(record.isCompleted)
        #expect(record.date == day(-40))
    }

    @Test func aFutureDateIsStoredAsPlanned() throws {
        let record = try log.saveVaccine(vaccineDraft(at: 12, repeatRule: .yearly), for: pet, now: testNow)

        #expect(record.isCompleted == false)
        #expect(record.completedAt == nil)
        #expect(pet.vaccines.count == 1, "Programar no crea además una 'próxima'")
    }

    @Test func repeatingCreatesTheNextDate() throws {
        try log.saveDeworming(dewormingDraft(repeatRule: quarterly), for: pet, now: testNow)

        let next = try #require(pending.first)
        #expect(pending.count == 1)
        #expect(next.date == makeDate(month: 9, day: 15))
        #expect(next.productName == "Drontal Plus")
        #expect(next.kind == .internal)
        #expect(next.repeatRule == quarterly)
    }

    @Test func loggingAgainReplacesTheNextDateInsteadOfStackingThem() throws {
        try log.saveDeworming(dewormingDraft(at: -90, repeatRule: quarterly), for: pet, now: testNow)
        try log.saveDeworming(dewormingDraft("Milbemax", at: 0, repeatRule: quarterly), for: pet, now: testNow)

        #expect(applied.count == 2)
        #expect(pending.count == 1)
        #expect(pending.first?.date == makeDate(month: 9, day: 15))
        #expect(pending.first?.productName == "Milbemax")
    }

    @Test func nextDatesOfOneKindDoNotTouchTheOther() throws {
        try log.saveDeworming(dewormingDraft("Bravecto", kind: .external, repeatRule: quarterly), for: pet, now: testNow)
        try log.saveDeworming(dewormingDraft("Drontal", kind: .internal, repeatRule: quarterly), for: pet, now: testNow)

        #expect(pending.count == 2)
        #expect(Set(pending.map(\.kind)) == [.internal, .external])
    }

    @Test func vaccinesAreScheduledPerName() throws {
        try log.saveVaccine(vaccineDraft("Antirrábica", repeatRule: .yearly), for: pet, now: testNow)
        try log.saveVaccine(vaccineDraft("Polivalente", repeatRule: .yearly), for: pet, now: testNow)
        try log.saveVaccine(vaccineDraft("antirrabica", repeatRule: .yearly), for: pet, now: testNow)

        let plannedNames = pet.vaccines.filter { !$0.isCompleted }.map(\.vaccineName).sorted()
        #expect(plannedNames == ["Polivalente", "antirrabica"])
    }

    @Test func withoutRepeatASoonPlannedDateCountsAsDone() throws {
        let soon = Deworming(date: day(5), pet: pet, productName: "Drontal")
        let farAway = Deworming(date: day(200), pet: pet, productName: "Drontal")
        context.insert(soon)
        context.insert(farAway)

        try log.saveDeworming(dewormingDraft(), for: pet, now: testNow)

        #expect(pending.map(\.date) == [day(200)])
    }

    // MARK: Cumplir algo pendiente

    @Test func fulfillingAPlannedRecordTurnsItIntoHistory() throws {
        let planned = try log.saveDeworming(dewormingDraft(at: 3, repeatRule: quarterly), for: pet, now: testNow)
        #expect(planned.isCompleted == false)

        let draft = RecordDraft(deworming: planned, applyingToday: true, now: testNow)
        let fulfilled = try log.saveDeworming(draft, for: pet, editing: planned, now: testNow)

        #expect(fulfilled.id == planned.id, "Es el mismo registro, no una copia")
        #expect(fulfilled.isCompleted)
        #expect(fulfilled.date == testNow)
        #expect(applied.count == 1)
        #expect(pending.count == 1)
        #expect(pending.first?.date == makeDate(month: 9, day: 15))
    }

    // MARK: Editar

    @Test func fixingATypoDoesNotMoveTheNextDate() throws {
        let record = try log.saveDeworming(dewormingDraft("Drontl", repeatRule: quarterly), for: pet, now: testNow)
        let next = try #require(pending.first)
        next.date = day(120)

        var draft = RecordDraft(deworming: record, applyingToday: false)
        draft.name = "Drontal"
        try log.saveDeworming(draft, for: pet, editing: record, now: testNow)

        #expect(record.productName == "Drontal")
        #expect(pending.map(\.date) == [day(120)], "La fecha que ajustó el usuario se respeta")
    }

    @Test func changingTheDateOfTheLatestApplicationMovesTheNextDate() throws {
        let record = try log.saveDeworming(dewormingDraft(repeatRule: quarterly), for: pet, now: testNow)

        var draft = RecordDraft(deworming: record, applyingToday: false)
        draft.date = makeDate(month: 6, day: 1)
        try log.saveDeworming(draft, for: pet, editing: record, now: testNow)

        #expect(pending.map(\.date) == [makeDate(month: 9, day: 1)])
    }

    @Test func correctingAnOldEntryLeavesTheScheduleAlone() throws {
        let old = try log.saveDeworming(dewormingDraft(at: -200, repeatRule: quarterly), for: pet, now: testNow)
        try log.saveDeworming(dewormingDraft(at: 0, repeatRule: quarterly), for: pet, now: testNow)

        var draft = RecordDraft(deworming: old, applyingToday: false)
        draft.date = day(-210)
        try log.saveDeworming(draft, for: pet, editing: old, now: testNow)

        #expect(pending.map(\.date) == [makeDate(month: 9, day: 15)])
    }

    // MARK: Peso y borrado

    @Test func savesAndEditsWeight() throws {
        let entry = try log.saveWeight(RecordDraft(kind: .weight, date: day(-1), weightKg: 9.4), for: pet)
        #expect(pet.weights.count == 1)

        try log.saveWeight(RecordDraft(kind: .weight, date: day(-1), notes: "En el veterinario", weightKg: 9.6),
                           for: pet, editing: entry)
        #expect(pet.weights.count == 1)
        #expect(entry.weightKg == 9.6)
        #expect(entry.notes == "En el veterinario")
    }

    @Test func deleteRemovesTheRecord() throws {
        let record = try log.saveVaccine(vaccineDraft(), for: pet, now: testNow)
        try log.delete(record)
        #expect(try context.fetchCount(FetchDescriptor<Vaccine>()) == 0)
    }
}

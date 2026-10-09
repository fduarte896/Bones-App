import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.logging))
struct RecordDraftPrefillTests {
    let context: ModelContext
    let pet: Pet

    init() throws {
        context = try makeContext()
        pet = try makePet(in: context)
    }

    private func summary() -> PetHealthSummary {
        PetHealthSummary(pet: pet, now: testNow, calendar: testCalendar)
    }

    @Test func firstDewormingStartsBlankWithTheUsualInterval() {
        let internalDraft = RecordDraft.new(kind: .deworming, dewormingKind: .internal, summary: summary())
        let externalDraft = RecordDraft.new(kind: .deworming, dewormingKind: .external, summary: summary())

        #expect(internalDraft.name.isEmpty)
        #expect(internalDraft.repeatRule == RepeatRule(value: 3, unit: .months))
        #expect(externalDraft.repeatRule == RepeatRule(value: 1, unit: .months))
    }

    @Test func proposesTheProductAndIntervalUsedLastTime() throws {
        let log = HealthLog(context: context, calendar: testCalendar)
        let everyTwoMonths = RepeatRule(value: 2, unit: .months)
        try log.saveDeworming(
            RecordDraft(kind: .deworming, name: "Milbemax", date: day(-30), repeatRule: everyTwoMonths),
            for: pet, now: testNow
        )

        let draft = RecordDraft.new(kind: .deworming, dewormingKind: .internal, summary: summary())
        #expect(draft.name == "Milbemax")
        #expect(draft.repeatRule == everyTwoMonths)
    }

    @Test func newVaccinesRepeatYearlyByDefault() {
        let draft = RecordDraft.new(kind: .vaccine, vaccineName: "Antirrábica", summary: summary())
        #expect(draft.name == "Antirrábica")
        #expect(draft.repeatRule == .yearly)
    }

    @Test func newWeightStartsFromTheLastOne() {
        context.insert(WeightEntry(date: day(-3), pet: pet, weightKg: 9.4))
        let draft = RecordDraft.new(kind: .weight, summary: summary())
        #expect(draft.weightKg == 9.4)
    }

    @Test func fulfillingProposesTodayButEditingKeepsThePlannedDate() {
        let planned = Vaccine(date: day(8), pet: pet, vaccineName: "Antirrábica")
        context.insert(planned)

        #expect(RecordDraft(vaccine: planned, applyingToday: true, now: testNow).date == testNow)
        #expect(RecordDraft(vaccine: planned, applyingToday: false, now: testNow).date == day(8))
    }
}

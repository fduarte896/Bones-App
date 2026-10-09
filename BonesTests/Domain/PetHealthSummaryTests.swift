import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.summary))
struct PetHealthSummaryTests {
    let context: ModelContext
    let pet: Pet

    init() throws {
        context = try makeContext()
        pet = try makePet(in: context)
    }

    private func summary() -> PetHealthSummary {
        PetHealthSummary(pet: pet, now: testNow, calendar: testCalendar)
    }

    @discardableResult
    private func addDeworming(_ product: String, kind: DewormingKind = .internal, at offset: Int, applied: Bool) -> Deworming {
        let record = Deworming(date: day(offset), pet: pet, kind: kind, productName: product)
        record.isCompleted = applied
        context.insert(record)
        return record
    }

    @discardableResult
    private func addVaccine(_ name: String, at offset: Int, applied: Bool) -> Vaccine {
        let record = Vaccine(date: day(offset), pet: pet, vaccineName: name)
        record.isCompleted = applied
        context.insert(record)
        return record
    }

    @Test func emptyPetHasNothingRecorded() {
        let summary = summary()
        #expect(summary.vaccines.isEmpty)
        #expect(summary.internalDeworming.status == .unrecorded)
        #expect(summary.externalDeworming.status == .unrecorded)
        #expect(summary.weight == nil)
        #expect(summary.needingAttention.isEmpty)
    }

    @Test func answersWhenAndWithWhatForDeworming() {
        addDeworming("Endogard", at: -200, applied: true)
        addDeworming("Drontal Plus", at: -61, applied: true)
        let next = addDeworming("Drontal Plus", at: 31, applied: false)

        let item = summary().internalDeworming
        #expect(item.lastDate == day(-61))
        #expect(item.lastDetail == "Drontal Plus")
        #expect(item.nextDate == day(31))
        #expect(item.nextRecordID == next.id)
        #expect(item.status == .upToDate(daysLeft: 31))
    }

    @Test func internalAndExternalAreTrackedSeparately() {
        addDeworming("Drontal Plus", kind: .internal, at: -10, applied: true)
        addDeworming("Bravecto", kind: .external, at: -80, applied: true)

        let summary = summary()
        #expect(summary.internalDeworming.lastDetail == "Drontal Plus")
        #expect(summary.externalDeworming.lastDetail == "Bravecto")
        #expect(summary.externalDeworming.lastDate == day(-80))
    }

    @Test func plannedDatesBeforeTheLastApplicationNoLongerCount() {
        addDeworming("Endogard", at: -10, applied: false)
        addDeworming("Drontal Plus", at: 0, applied: true)

        let item = summary().internalDeworming
        #expect(item.nextDate == nil, "Lo programado antes de la última aplicación ya quedó atrás")
        #expect(item.status == .noNextDate)
    }

    @Test func groupsVaccinesByNameIgnoringLegacyDoseSuffix() {
        addVaccine("Rabia (dosis 1/2)", at: -400, applied: true)
        addVaccine("rabia", at: -35, applied: true)
        addVaccine("Polivalente", at: -60, applied: true)

        let vaccines = summary().vaccines
        #expect(vaccines.count == 2)
        let rabies = try? #require(vaccines.first { $0.title.lowercased() == "rabia" })
        #expect(rabies?.lastDate == day(-35))
    }

    @Test func vaccinesNeedingAttentionComeFirst() {
        addVaccine("Antirrábica", at: -300, applied: true)
        addVaccine("Antirrábica", at: 65, applied: false)
        addVaccine("Zeta", at: -370, applied: true)
        addVaccine("Zeta", at: -5, applied: false)
        addVaccine("Moquillo", at: 12, applied: false)

        #expect(summary().vaccines.map(\.title) == ["Zeta", "Moquillo", "Antirrábica"])
    }

    @Test func attentionListsOverdueAndSoonMostUrgentFirst() {
        addVaccine("Antirrábica", at: 20, applied: false)
        addDeworming("Drontal", at: -3, applied: false)
        addVaccine("Polivalente", at: 90, applied: false)

        let attention = summary().needingAttention
        #expect(attention.map(\.kind) == [.deworming(.internal), .vaccine(key: "antirrabica")])
    }

    @Test func weightReportsLatestAndChange() throws {
        context.insert(WeightEntry(date: day(-60), pet: pet, weightKg: 8.7))
        context.insert(WeightEntry(date: day(-3), pet: pet, weightKg: 9.4))
        context.insert(WeightEntry(date: day(-30), pet: pet, weightKg: 9.1))

        let weight = try #require(summary().weight)
        #expect(weight.latestKg == 9.4)
        #expect(weight.latestDate == day(-3))
        #expect(abs((weight.deltaKg ?? 0) - 0.3) < 0.0001)
        #expect(weight.recent.map(\.kg) == [8.7, 9.1, 9.4])
    }

    @Test func singleWeightHasNoChange() throws {
        context.insert(WeightEntry(date: day(-3), pet: pet, weightKg: 9.4))
        let weight = try #require(summary().weight)
        #expect(weight.deltaKg == nil)
    }
}

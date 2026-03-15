import Testing
import Foundation
import SwiftData
@testable import Bones

@MainActor
@Suite(.tags(.models, .parsing))
struct WeightAnomalyDetectorTests {
    let context: ModelContext
    let pet: Pet
    let detector = WeightAnomalyDetector()

    init() throws {
        context = try makeContext()
        pet = makePet(in: context)
    }

    private func insertWeights(_ values: [(day: Int, kg: Double)]) throws {
        for v in values {
            let entry = WeightEntry(date: makeDate(day: v.day), pet: pet, weightKg: v.kg)
            context.insert(entry)
        }
        try context.save()
    }

    @Test func analyze_lessThan3Weights_returnsNil() throws {
        try insertWeights([(1, 10.0), (2, 10.5)])
        let result = detector.analyze(petID: pet.id, context: context)
        #expect(result == nil)
    }

    @Test func analyze_stableWeights_notAnomalous() throws {
        try insertWeights([
            (1, 10.0), (2, 10.1), (3, 9.9),
            (4, 10.0), (5, 10.2)
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.isAnomalous == false)
    }

    @Test func analyze_extremeSpike_isAnomalous() throws {
        try insertWeights([
            (1, 10.0), (2, 10.1), (3, 9.9),
            (4, 10.0), (5, 20.0)  // big spike as most recent
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.isAnomalous == true)
    }

    @Test func analyze_zScore_positiveForHighWeight() throws {
        try insertWeights([
            (1, 10.0), (2, 10.0), (3, 10.0),
            (4, 10.0), (5, 15.0)
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.zScore > 0)
    }

    @Test func analyze_zScore_negativeForLowWeight() throws {
        try insertWeights([
            (1, 10.0), (2, 10.0), (3, 10.0),
            (4, 10.0), (5, 5.0)
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.zScore < 0)
    }

    @Test func analyze_mean_correctCalculation() throws {
        try insertWeights([
            (1, 8.0), (2, 10.0), (3, 12.0),
            (4, 10.0), (5, 10.0)  // latest = 10.0, baseline = [10.0, 12.0, 10.0, 8.0]
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.mean == 10.0, "Mean of [10.0, 12.0, 10.0, 8.0] should be 10.0")
    }

    @Test func analyze_std_nonZero() throws {
        try insertWeights([
            (1, 8.0), (2, 10.0), (3, 12.0),
            (4, 10.0), (5, 10.0)
        ])
        let result = try #require(detector.analyze(petID: pet.id, context: context))
        #expect(result.std > 0)
    }
}

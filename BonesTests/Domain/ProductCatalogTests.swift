import Testing
import Foundation
@testable import Bones

struct ProductCatalogTests {
    @Test func usedNamesComeFirstMostRecentFirstWithoutDuplicates() {
        let used = [("Drontal Plus", day(-200)), ("Milbemax", day(-20)), ("drontal plus", day(-100))]
        let suggestions = ProductCatalog.suggestions(used: used, defaults: ["Panacur", "Milbemax"])
        #expect(suggestions == ["Milbemax", "drontal plus", "Panacur"])
    }

    @Test func respectsTheLimit() {
        let suggestions = ProductCatalog.suggestions(used: [], defaults: ["A", "B", "C", "D"], limit: 2)
        #expect(suggestions == ["A", "B"])
    }

    @Test func skipsBlankNamesAndLegacyDoseSuffixes() {
        let used = [("", day(-1)), ("Rabia (dosis 1/2)", day(-2))]
        #expect(ProductCatalog.suggestions(used: used, defaults: []) == ["Rabia"])
    }

    @Test(arguments: Species.allCases)
    func everySpeciesHasVaccineSuggestions(species: Species) {
        #expect(ProductCatalog.defaultVaccines(for: species).isEmpty == false)
    }
}

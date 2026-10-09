import Testing
import Foundation
@testable import Bones

@Suite(.tags(.migration))
struct DoseLabelTests {
    @Test func splitsLegacyDoseSuffix() {
        let parts = DoseLabel.split("Drontal Plus (dosis 1/2)")
        #expect(parts.base == "Drontal Plus")
        #expect(parts.dose == "Dosis 1/2")
    }

    @Test(arguments: ["Rabia", "Polivalente (DHPPi)", "  Milbemax  ", "(dosis 1/2)", ""])
    func leavesOtherNamesAlone(name: String) {
        let parts = DoseLabel.split(name)
        #expect(parts.dose == nil)
        #expect(parts.base == name.trimmingCharacters(in: .whitespaces))
    }

    @Test func vaccineKeyIgnoresCaseAccentsDoseAndSpacing() {
        let key = CareKind.vaccineKey(for: "Antirrábica")
        #expect(CareKind.vaccineKey(for: "antirrabica") == key)
        #expect(CareKind.vaccineKey(for: "  ANTIRRÁBICA  (dosis 2/3)") == key)
        #expect(CareKind.vaccineKey(for: "Polivalente") != key)
    }
}

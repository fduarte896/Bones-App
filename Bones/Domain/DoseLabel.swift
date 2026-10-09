import Foundation

/// Las versiones anteriores escribían la dosis dentro del nombre: "Rabia (dosis 2/3)".
enum DoseLabel {
    /// Separa "Rabia (dosis 2/3)" en ("Rabia", "Dosis 2/3"). Sin sufijo devuelve el nombre tal cual.
    static func split(_ name: String) -> (base: String, dose: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(")"),
              let marker = trimmed.range(of: "(dosis ", options: [.backwards, .caseInsensitive]) else {
            return (trimmed, nil)
        }
        let base = trimmed[..<marker.lowerBound].trimmingCharacters(in: .whitespaces)
        let inside = trimmed[marker.upperBound..<trimmed.index(before: trimmed.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty, !inside.isEmpty else { return (trimmed, nil) }
        return (base, "Dosis \(inside)")
    }
}

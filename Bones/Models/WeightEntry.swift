import Foundation
import SwiftData

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Peso"
    var notes: String?
    var isCompleted: Bool = true
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?
    var completedAt: Date?

    var weightKg: Double

    init(date: Date, pet: Pet, weightKg: Double, notes: String? = nil) {
        self.date = date
        self.pet = pet
        self.weightKg = weightKg
        self.notes = notes
    }
}

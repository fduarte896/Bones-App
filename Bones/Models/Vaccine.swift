import Foundation
import SwiftData

@Model
final class Vaccine: HealthRecord {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Vacuna"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    var vaccineName: String
    var manufacturer: String?

    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?

    init(date: Date,
         pet: Pet,
         vaccineName: String,
         manufacturer: String? = nil,
         notes: String? = nil,
         prescriptionImageData: Data? = nil) {
        self.date = date
        self.pet = pet
        self.vaccineName = vaccineName
        self.manufacturer = manufacturer
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
    }
}

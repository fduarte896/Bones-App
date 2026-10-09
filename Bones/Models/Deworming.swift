import Foundation
import SwiftData

@Model
final class Deworming: HealthRecord {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var title: String = "Desparasitación"
    var notes: String?
    var isCompleted: Bool = false
    var isRecurring: Bool = false
    var rrule: String?
    var pet: Pet?

    /// Heredado de versiones anteriores, que agrupaban dosis en series. Ya no se usa.
    var seriesID: UUID?

    /// Qué se le dio. Las versiones anteriores lo guardaban en `notes`;
    /// `LegacyDataMigrator` lo mueve aquí.
    var productName: String = ""

    /// `DewormingKind.rawValue`. Se guarda como texto para que la migración ligera
    /// pueda rellenar el valor por defecto en las filas existentes.
    var kindRaw: String = DewormingKind.internal.rawValue

    @Attribute(.externalStorage) var prescriptionImageData: Data?

    var completedAt: Date?

    var kind: DewormingKind {
        get { DewormingKind(rawValue: kindRaw) ?? .internal }
        set { kindRaw = newValue.rawValue }
    }

    init(date: Date,
         pet: Pet,
         kind: DewormingKind = .internal,
         productName: String = "",
         notes: String? = nil,
         prescriptionImageData: Data? = nil) {
        self.date = date
        self.pet = pet
        self.kindRaw = kind.rawValue
        self.productName = productName
        self.notes = notes
        self.prescriptionImageData = prescriptionImageData
    }
}

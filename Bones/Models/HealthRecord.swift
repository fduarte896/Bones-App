import Foundation
import SwiftData

/// Lo que comparten vacunas y desparasitaciones.
///
/// Un registro con `isCompleted == true` es algo que ya se aplicó en `date`.
/// Uno con `isCompleted == false` es la próxima fecha en la que toca.
protocol HealthRecord: PersistentModel {
    var id: UUID { get set }
    var date: Date { get set }
    var notes: String? { get set }
    var isCompleted: Bool { get set }
    var completedAt: Date? { get set }
    var isRecurring: Bool { get set }
    var rrule: String? { get set }
    var prescriptionImageData: Data? { get set }
    var pet: Pet? { get set }
}

extension HealthRecord {
    var repeatRule: RepeatRule? {
        get { rrule.flatMap(RepeatRule.init(rrule:)) }
        set {
            rrule = newValue?.rrule
            isRecurring = newValue != nil
        }
    }
}

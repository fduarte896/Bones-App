import Foundation

enum AppStorageKey {
    static let selectedPetID       = "selectedPetID"
    static let reminderLeadDays    = "reminderLeadDays"
    static let didMigrateToRecords = "didMigrateToRecords.v2"
}

enum ReminderDefaults {
    static let leadDays = 3
    /// Hora del día a la que llegan los recordatorios.
    static let hour = 9
}

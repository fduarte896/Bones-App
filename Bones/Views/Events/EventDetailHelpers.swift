import SwiftUI
import SwiftData

// MARK: - Binding helpers para opcionales

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith placeholder: String) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue }
        )
    }
}

extension Binding where Value == Double {
    init(_ source: Binding<Double?>, replacingNilWith placeholder: Double) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

// MARK: - Propagación de prescripción a toda la serie

func propagatePrescriptionForVaccine(_ vac: Vaccine, with data: Data?, in context: ModelContext) {
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

func propagatePrescriptionForDeworming(_ dew: Deworming, with data: Data?, in context: ModelContext) {
    guard let petID = dew.pet?.id else { return }
    let baseNotes = DoseSeries.normalizeNotes(dew.notes)
    let predicate = #Predicate<Deworming> { d in d.pet?.id == petID }
    let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))) ?? []
    fetched.filter { DoseSeries.normalizeNotes($0.notes) == baseNotes }.forEach { $0.prescriptionImageData = data }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

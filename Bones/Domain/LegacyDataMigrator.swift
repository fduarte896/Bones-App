import Foundation
import SwiftData

/// Adapta los datos de versiones anteriores al modelo de registro.
///
/// Antes, el producto antiparasitario se escribía en las notas y la dosis iba dentro
/// del nombre ("Drontal Plus (dosis 1/2)"). Esta pasada mueve cada cosa a su campo.
/// No borra registros ni cambia qué está aplicado y qué está pendiente.
@MainActor
enum LegacyDataMigrator {
    static func runIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: AppStorageKey.didMigrateToRecords) else { return }
        do {
            try migrate(context: context)
            defaults.set(true, forKey: AppStorageKey.didMigrateToRecords)
        } catch {
            // Se reintenta en el próximo arranque; los datos siguen intactos.
            context.rollback()
        }
    }

    static func migrate(context: ModelContext) throws {
        for deworming in try context.fetch(FetchDescriptor<Deworming>()) where deworming.productName.isEmpty {
            guard let legacy = deworming.notes?.nilIfBlank else { continue }
            let parts = DoseLabel.split(legacy)
            deworming.productName = parts.base.capitalizingFirstLetter
            deworming.kind = ProductCatalog.guessKind(forProduct: parts.base)
            deworming.notes = parts.dose
        }

        for vaccine in try context.fetch(FetchDescriptor<Vaccine>()) {
            let parts = DoseLabel.split(vaccine.vaccineName)
            guard let dose = parts.dose else { continue }
            vaccine.vaccineName = parts.base
            vaccine.notes = [dose, vaccine.notes?.nilIfBlank].compactMap(\.self).joined(separator: " · ")
        }

        try context.save()
    }
}

extension String {
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

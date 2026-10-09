import SwiftUI
import SwiftData

@main
struct BonesApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Pet.self, Vaccine.self, Deworming.self, WeightEntry.self)
        } catch {
            fatalError("No se pudo abrir la base de datos de Bones: \(error)")
        }
        LegacyDataMigrator.runIfNeeded(context: container.mainContext)
        ReminderScheduler.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, BonesFormat.locale)
        }
        .modelContainer(container)
    }
}

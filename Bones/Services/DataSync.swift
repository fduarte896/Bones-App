import SwiftData

/// Lo que hay que poner al día cada vez que cambian los datos: recordatorios y widget.
@MainActor
enum DataSync {
    static func afterChange(in context: ModelContext) {
        WidgetDataPublisher.update(using: context)
        Task {
            await ReminderScheduler.shared.resync(context: context)
        }
    }
}

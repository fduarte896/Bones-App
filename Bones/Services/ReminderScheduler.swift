import Foundation
import SwiftData
import UserNotifications

/// Mantiene las notificaciones locales iguales a las fechas pendientes guardadas.
///
/// En vez de programar y cancelar aviso por aviso, cada cambio vuelve a calcular
/// la lista completa. Son pocas fechas y así nunca queda un aviso huérfano.
@MainActor
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    /// iOS guarda como máximo 64 notificaciones locales por app.
    private static let maxScheduled = 60

    private var center: UNUserNotificationCenter { .current() }

    func configure() {
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Vuelve a programar todos los avisos. Pide permiso la primera vez que hay algo que avisar.
    func resync(context: ModelContext, defaults: UserDefaults = .standard) async {
        let plans = Self.plans(context: context, leadDays: Self.leadDays(in: defaults), now: .now)

        var status = await authorizationStatus()
        if status == .notDetermined, !plans.isEmpty {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await authorizationStatus()
        }

        center.removeAllPendingNotificationRequests()
        guard status == .authorized || status == .provisional else { return }

        for plan in plans.prefix(Self.maxScheduled) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger))
        }
    }

    static func leadDays(in defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: AppStorageKey.reminderLeadDays) as? Int ?? ReminderDefaults.leadDays
    }

    static func plans(context: ModelContext, leadDays: Int, now: Date, calendar: Calendar = .current) -> [ReminderPlan] {
        let vaccines = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: #Predicate { !$0.isCompleted }))) ?? []
        let dewormings = (try? context.fetch(FetchDescriptor<Deworming>(predicate: #Predicate { !$0.isCompleted }))) ?? []

        let vaccinePlans = vaccines.flatMap { vaccine in
            ReminderPlan.plans(recordID: vaccine.id,
                               petName: vaccine.pet?.name ?? "Bones",
                               subject: vaccine.displayName,
                               due: vaccine.date, leadDays: leadDays, now: now, calendar: calendar)
        }
        let dewormingPlans = dewormings.flatMap { deworming in
            ReminderPlan.plans(recordID: deworming.id,
                               petName: deworming.pet?.name ?? "Bones",
                               subject: deworming.kind.longName,
                               due: deworming.date, leadDays: leadDays, now: now, calendar: calendar)
        }
        return (vaccinePlans + dewormingPlans).sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

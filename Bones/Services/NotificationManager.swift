//
//  NotificationManager.swift
//  Bones
//
//  Created by Felipe Duarte on 16/07/25.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    private override init() { }
    
    // Call once at app launch
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        print("🔔 Notifications granted? \(granted == true)")
    }
    
    // Schedules one notification X seconds before the event.date
    func scheduleNotification(
        id: UUID,
        title: String,
        body: String,
        fireDate: Date,
        advance: TimeInterval = 3600   // default: 1 h antes
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        
        let triggerDate = fireDate.addingTimeInterval(-advance)
        guard triggerDate > Date() else { return } // no programar si ya pasó
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("⚠️ Notification error:", error) }
        }
    }
    
    // Cancela (por ej. si el usuario borra el evento)
    func cancelNotification(id: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
    
    // MARK: UNUserNotificationCenterDelegate (opcional)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Mostrar también si la app está en primer plano
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let eventsDidChange = Notification.Name("eventsDidChange")
}

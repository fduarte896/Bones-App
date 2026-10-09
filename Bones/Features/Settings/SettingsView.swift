import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(AppStorageKey.reminderLeadDays) private var leadDays = ReminderDefaults.leadDays

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Avisarme", selection: $leadDays) {
                        Text("Solo el mismo día").tag(0)
                        Text("1 día antes").tag(1)
                        Text("3 días antes").tag(3)
                        Text("1 semana antes").tag(7)
                        Text("2 semanas antes").tag(14)
                    }
                    if notificationStatus == .denied {
                        Button("Activar notificaciones en Ajustes", systemImage: "bell.slash", action: openNotificationSettings)
                    }
                } header: {
                    Text("Recordatorios")
                } footer: {
                    Text(notificationStatus == .denied
                         ? "Las notificaciones están desactivadas, así que Bones no puede avisarte."
                         : "Recibirás un aviso antes de cada fecha y otro el mismo día, a las \(ReminderDefaults.hour):00.")
                }

                Section {
                    LabeledContent("Versión", value: version)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", action: close)
                }
            }
            .task {
                notificationStatus = await ReminderScheduler.shared.authorizationStatus()
            }
            .onChange(of: leadDays) {
                DataSync.afterChange(in: context)
            }
        }
    }

    private func close() {
        dismiss()
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container(seeded: false))
}

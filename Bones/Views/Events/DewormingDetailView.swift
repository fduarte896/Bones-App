import SwiftUI
import SwiftData

struct DewormingDetailView: View {
    @Bindable var dew: Deworming
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            EventDetailHeader(
                pet: dew.pet,
                title: dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación",
                icon: "ladybug.fill",
                isCompleted: dew.isCompleted,
                date: dew.date
            )

            Section("Fecha") {
                DatePicker("Programado para", selection: $dew.date, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: dew.date) { _, _ in reschedule(for: dew) }
            }

            Section("Notas") {
                TextEditor(text: Binding($dew.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: dew.notes) { _, _ in save() }
            }

            PrescriptionSection(imageData: $dew.prescriptionImageData) {
                propagatePrescriptionForDeworming(dew, with: dew.prescriptionImageData, in: context)
            }

            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }

    private func save() {
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }

    private func reschedule(for e: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: e.id)
        let title = e.displayType.isEmpty ? "Evento" : e.displayType
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: "\(e.pet?.name ?? "") – \(e.displayName)", fireDate: e.date, advance: 0)
        save()
    }
}

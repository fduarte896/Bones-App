import SwiftUI
import SwiftData

struct VaccineDetailView: View {
    @Bindable var vac: Vaccine
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            EventDetailHeader(
                pet: vac.pet,
                title: DoseSeries.splitDoseBase(from: vac.vaccineName),
                accentColor: .bonesVaccine,
                isCompleted: vac.isCompleted,
                date: vac.date
            )

            Section("Información") {
                TextField("Nombre", text: $vac.vaccineName)
                    .onChange(of: vac.vaccineName) { _, _ in save() }
                TextField("Fabricante", text: Binding($vac.manufacturer, replacingNilWith: ""))
                    .onChange(of: vac.manufacturer) { _, _ in save() }
            }

            Section("Fecha") {
                DatePicker("Programado para", selection: $vac.date, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: vac.date) { _, _ in reschedule(for: vac) }
            }

            Section("Notas") {
                TextEditor(text: Binding($vac.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: vac.notes) { _, _ in save() }
            }

            PrescriptionSection(imageData: $vac.prescriptionImageData) {
                propagatePrescriptionForVaccine(vac, with: vac.prescriptionImageData, in: context)
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

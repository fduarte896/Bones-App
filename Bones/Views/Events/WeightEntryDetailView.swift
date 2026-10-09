import SwiftUI
import SwiftData

struct WeightEntryDetailView: View {
    @Bindable var weight: WeightEntry
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            EventDetailHeader(
                pet: weight.pet,
                title: String(format: "%.1f kg", weight.weightKg),
                accentColor: .bonesWeight,
                isCompleted: true,
                date: weight.date
            )

            Section("Medición") {
                TextField("Peso (kg)", value: $weight.weightKg, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .onChange(of: weight.weightKg) { _, _ in save() }
            }

            Section("Fecha") {
                DatePicker("Tomado el", selection: $weight.date, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: weight.date) { _, _ in reschedule(for: weight) }
            }

            Section("Notas") {
                TextEditor(text: Binding($weight.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: weight.notes) { _, _ in save() }
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

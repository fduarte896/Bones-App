import SwiftUI
import SwiftData

struct WeightHistoryView: View {
    let pet: Pet
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var request: RecordRequest?

    var body: some View {
        let entries = pet.weights.sorted { $0.date > $1.date }
        let summary = WeightSummary(entries: entries, recentLimit: 60)

        List {
            if let summary {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.row) {
                        Text(BonesFormat.weight(summary.latestKg))
                            .font(.title)
                            .bold()
                            .contentTransition(.numericText(value: summary.latestKg))
                        if summary.recent.count > 1 {
                            WeightChart(points: summary.recent)
                        }
                    }
                }
            }

            Section("Historial") {
                ForEach(entries) { entry in
                    Button {
                        edit(entry)
                    } label: {
                        RecordRow(title: BonesFormat.weight(entry.weightKg),
                                  subtitle: "\(BonesFormat.day(entry.date)) · \(BonesFormat.ago(entry.date).lowercased())",
                                  notes: entry.notes?.nilIfBlank)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Eliminar", systemImage: "trash", role: .destructive) { delete(entry) }
                    }
                }
            }
        }
        .animation(.default, value: entries.map(\.id))
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Sin pesos registrados", systemImage: "scalemass")
            }
        }
        .navigationTitle("Peso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Registrar peso", systemImage: "plus", action: add)
            }
        }
        .sheet(item: $request) { request in
            RecordSheet(request: request, onSaved: onSaved)
        }
    }

    private func add() {
        request = RecordRequest(pet: pet, kind: .weight)
    }

    private func edit(_ entry: WeightEntry) {
        request = RecordRequest(pet: pet, kind: .weight, target: .weight(entry))
    }

    private func delete(_ entry: WeightEntry) {
        try? HealthLog(context: context).delete(entry)
        onSaved()
    }
}

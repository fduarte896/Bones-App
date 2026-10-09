import SwiftUI
import SwiftData

/// Historial de una vacuna o de un tipo de desparasitación.
struct CareHistoryView: View {
    let pet: Pet
    let kind: CareKind
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var request: RecordRequest?

    private var recordKind: RecordDraft.Kind {
        switch kind {
        case .vaccine:   .vaccine
        case .deworming: .deworming
        }
    }

    private func title(for item: CareItem?) -> String {
        switch kind {
        case .vaccine:                      item?.title ?? "Vacuna"
        case .deworming(let dewormingKind): dewormingKind.longName
        }
    }

    var body: some View {
        let entries = HistoryEntry.entries(for: kind, pet: pet)
        let planned = entries.filter { !$0.isApplied }.sorted { $0.date < $1.date }
        let applied = entries.filter(\.isApplied).sorted { $0.date > $1.date }
        let item = PetHealthSummary(pet: pet).item(for: kind)

        List {
            if let item {
                Section {
                    CareHistoryHeader(item: item)
                }
            }

            if !planned.isEmpty {
                Section(planned.count == 1 ? "Próxima" : "Programadas") {
                    ForEach(planned) { entry in
                        Button {
                            edit(entry)
                        } label: {
                            RecordRow(title: BonesFormat.day(entry.date),
                                      subtitle: plannedSubtitle(for: entry),
                                      notes: entry.notes)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Eliminar", systemImage: "trash", role: .destructive) { delete(entry) }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Registrar", systemImage: "checkmark") { fulfill(entry) }
                                .tint(.green)
                        }
                    }
                }
            }

            if !applied.isEmpty {
                Section("Historial") {
                    ForEach(applied) { entry in
                        Button {
                            edit(entry)
                        } label: {
                            RecordRow(title: appliedTitle(for: entry),
                                      subtitle: appliedSubtitle(for: entry),
                                      notes: entry.notes,
                                      hasPhoto: entry.hasPhoto)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Eliminar", systemImage: "trash", role: .destructive) { delete(entry) }
                        }
                    }
                }
            }
        }
        .animation(.default, value: entries.map(\.id))
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Sin registros", systemImage: "tray",
                                       description: Text("Lo que registres aparecerá aquí."))
            }
        }
        .navigationTitle(title(for: item))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Registrar", systemImage: "plus", action: add)
            }
        }
        .sheet(item: $request) { request in
            RecordSheet(request: request, onSaved: onSaved)
        }
    }

    // En desparasitación lo que distingue cada entrada es el producto; en vacunas, la fecha.

    private func appliedTitle(for entry: HistoryEntry) -> String {
        switch kind {
        case .vaccine:   BonesFormat.day(entry.date)
        case .deworming: entry.name
        }
    }

    private func appliedSubtitle(for entry: HistoryEntry) -> String {
        let ago = BonesFormat.ago(entry.date)
        return switch kind {
        case .vaccine:   [ago, entry.detail].compactMap(\.self).joined(separator: " · ")
        case .deworming: "\(BonesFormat.day(entry.date)) · \(ago.lowercased())"
        }
    }

    private func plannedSubtitle(for entry: HistoryEntry) -> String {
        let status = CareStatus(lastDate: nil, nextDate: entry.date, now: .now, calendar: .current)
        return BonesFormat.dueText(for: status) ?? ""
    }

    private func add() {
        if let item = PetHealthSummary(pet: pet).item(for: kind) {
            request = .adding(to: item, for: pet)
        } else {
            request = RecordRequest(pet: pet, kind: recordKind)
        }
    }

    private func edit(_ entry: HistoryEntry) {
        request = RecordRequest(pet: pet, kind: recordKind, target: entry.target)
    }

    private func fulfill(_ entry: HistoryEntry) {
        request = RecordRequest(pet: pet, kind: recordKind, target: entry.target, applyingToday: true)
    }

    private func delete(_ entry: HistoryEntry) {
        let log = HealthLog(context: context)
        switch entry.target {
        case .vaccine(let record):   try? log.delete(record)
        case .deworming(let record): try? log.delete(record)
        case .weight, .new:          break
        }
        onSaved()
    }
}

#Preview {
    let container = PreviewData.container()
    let pet = PreviewData.firstPet(in: container)
    return NavigationStack {
        CareHistoryView(pet: pet, kind: .deworming(.internal), onSaved: {})
    }
    .modelContainer(container)
}

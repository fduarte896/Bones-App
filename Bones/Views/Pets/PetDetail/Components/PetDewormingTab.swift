//
//  PetDewormingTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData

struct PetDewormingTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context

    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    @State private var pendingDelete: Deworming?

    @State private var pendingSeriesItems: [Deworming] = []
    @State private var pendingSeriesCount: Int = 0
    @State private var showingSeriesDeleteDialog = false

    @State private var expandedSeries: Set<String> = []

    var body: some View {
        List {
            if viewModel.dewormings.isEmpty {
                ContentUnavailableView("Sin desparasitaciones registradas",
                                       systemImage: "ladybug.fill")
            } else {
                ForEach(orderedSummaries) { summary in
                    Section {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    if expandedSeries.contains(summary.baseName) {
                                        expandedSeries.remove(summary.baseName)
                                    } else {
                                        expandedSeries.insert(summary.baseName)
                                    }
                                }
                            } label: {
                                DewormingSeriesRow(
                                    summary: summary,
                                    expanded: expandedSeries.contains(summary.baseName)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button { startDeleteSeries(summary) } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Eliminar serie")
                        }
                        .listRowSeparatorTint(Color.bonesRule)

                        if expandedSeries.contains(summary.baseName) {
                            ForEach(summary.items.sorted(by: { $0.date < $1.date }), id: \.id) { dew in
                                NavigationLink {
                                    EventDetailView(event: dew)
                                } label: {
                                    DewormingDoseRow(
                                        dew: dew,
                                        isNext: dew.id == summary.nextPending?.id,
                                        allDewormings: summary.items
                                    )
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        dew.isCompleted.toggle()
                                        NotificationManager.shared.cancelNotification(id: dew.id)
                                        try? context.save()
                                        viewModel.fetchEvents()
                                    } label: {
                                        Label("Completar", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        startDelete(for: dew)
                                    } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }
                                }
                                .listRowSeparatorTint(Color.bonesRule)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .background(Color.bonesBg)
        .onAppear {
            viewModel.fetchEvents()
            autoExpandCriticalSeries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            viewModel.fetchEvents()
            autoExpandCriticalSeries()
        }
        .confirmationDialog(
            "¿Eliminar también dosis futuras?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            if pendingFutureCount > 0 {
                Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                    deleteThisAndFuture()
                }
                Button("Eliminar solo esta", role: .destructive) {
                    if let dew = pendingDelete { deleteSingle(dew) }
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    if let dew = pendingDelete { deleteSingle(dew) }
                }
            }
            Button("Cancelar", role: .cancel) { clearPending() }
        } message: {
            if pendingFutureCount > 0 {
                Text("Se encontraron \(pendingFutureCount) dosis futuras relacionadas. ¿Quieres borrarlas también?")
            } else {
                Text("Esta acción no se puede deshacer.")
            }
        }
        .confirmationDialog(
            "¿Eliminar toda la serie?",
            isPresented: $showingSeriesDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Eliminar \(pendingSeriesCount) dosis", role: .destructive) {
                deleteSeries()
            }
            Button("Cancelar", role: .cancel) { clearSeriesPending() }
        } message: {
            Text("Se eliminarán todas las dosis de esta serie. Esta acción no se puede deshacer.")
        }
    }

    private var orderedSummaries: [PetDetailViewModel.DewormingSeriesSummary] {
        let now = Date()
        func priority(_ s: PetDetailViewModel.DewormingSeriesSummary) -> (Int, Date?, String) {
            let isOverdue = (s.nextPending?.date ?? now) < now && s.nextPending != nil
            return (isOverdue ? 0 : 1, s.nextPending?.date, s.baseName.lowercased())
        }
        return viewModel.dewormingSeriesSummaries.sorted { a, b in
            let pa = priority(a), pb = priority(b)
            if pa.0 != pb.0 { return pa.0 < pb.0 }
            if pa.1 != pb.1 { return (pa.1 ?? .distantFuture) < (pb.1 ?? .distantFuture) }
            return pa.2 < pb.2
        }
    }

    private func autoExpandCriticalSeries() {
        let now = Date()
        let soon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        for s in viewModel.dewormingSeriesSummaries {
            let hasOverdue = s.items.contains { !$0.isCompleted && $0.date < now }
            let nextSoon = s.nextPending.map { $0.date <= soon } ?? false
            if hasOverdue || nextSoon {
                expandedSeries.insert(s.baseName)
            }
        }
    }
}

// MARK: - Dose timeline

private struct DewormingDoseTimeline: View {
    let items: [Deworming]
    let nextPendingID: UUID?
    private let maxVisible = 8

    private var sorted: [Deworming] { items.sorted { $0.date < $1.date } }
    private var visible: [Deworming] { Array(sorted.prefix(maxVisible)) }
    private var overflow: Int { max(0, items.count - maxVisible) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { idx, dew in
                if idx > 0 {
                    let before = visible[idx - 1]
                    let color: Color = before.isCompleted ? Color.bonesOk.opacity(0.35)
                        : (!before.isCompleted && before.date < Date()) ? Color.bonesOverdue.opacity(0.25)
                        : Color.bonesRule
                    Rectangle().fill(color).frame(width: 16, height: 2)
                }
                DewormingDot(dew: dew, isNext: dew.id == nextPendingID)
            }
            if overflow > 0 {
                Rectangle().fill(Color.bonesRule).frame(width: 12, height: 2)
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.bonesInkFaint)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Color.bonesRule))
            }
        }
    }
}

private struct DewormingDot: View {
    let dew: Deworming
    let isNext: Bool

    var body: some View {
        let isOverdue = !dew.isCompleted && dew.date < Date()
        ZStack {
            if dew.isCompleted {
                Circle().fill(Color.bonesOk)
            } else if isOverdue {
                Circle().fill(Color.bonesOverdue)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
            } else if isNext {
                Circle().fill(Color.bonesDeworming)
                Circle().strokeBorder(Color.bonesDeworming.opacity(0.3), lineWidth: 3)
                    .padding(-3)
            } else {
                Circle().strokeBorder(Color.bonesInkFaint, lineWidth: 1.5)
                    .background(Circle().fill(Color.bonesBg))
            }
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Series row (card header)

private struct DewormingSeriesRow: View {
    let summary: PetDetailViewModel.DewormingSeriesSummary
    let expanded: Bool

    private var seriesStatus: HealthStatus {
        let now = Date()
        if summary.items.contains(where: { !$0.isCompleted && $0.date < now }) { return .overdue }
        if let next = summary.nextPending?.date,
           next.timeIntervalSince(now) < 7 * 24 * 3600 { return .soon }
        return .ok
    }

    private var seriesStatusLabel: String {
        switch seriesStatus {
        case .overdue:
            if let days = summary.overdueDays { return "Hace \(days) d" }
            return "Vencida"
        case .soon:
            if let next = summary.nextPending?.date { return bonesRelativeLabel(for: next) }
            return "Próxima"
        case .ok:
            if let next = summary.nextPending?.date { return bonesShortDate(next) }
            return "Al día"
        }
    }

    private var nextText: String {
        guard let next = summary.nextPending else { return "Sin próxima" }
        if let days = summary.overdueDays, days > 0, next.date < Date() {
            return "Hace \(days) d"
        }
        return bonesShortDate(next.date)
    }

    private var lastText: String {
        summary.lastCompleted.map { bonesShortDate($0.date) } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(summary.baseName)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.bonesInk)
                StatusPill(status: seriesStatus, label: seriesStatusLabel)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bonesInkFaint)
                    .rotationEffect(expanded ? .degrees(180) : .zero)
                    .animation(.spring(response: 0.3, dampingFraction: 0.82), value: expanded)
            }

            DewormingDoseTimeline(
                items: summary.items,
                nextPendingID: summary.nextPending?.id
            )

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Siguiente")
                        .font(.caption2).foregroundStyle(Color.bonesInkFaint)
                    Text(nextText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(seriesStatus == .overdue ? Color.bonesOverdue : Color.bonesInk)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Última")
                        .font(.caption2).foregroundStyle(Color.bonesInkFaint)
                    Text(lastText)
                        .font(.subheadline)
                        .foregroundStyle(Color.bonesInkSoft)
                }

                Spacer()

                let completed = summary.items.filter(\.isCompleted).count
                let total = summary.items.count
                Text("\(completed)/\(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.bonesInkSoft)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.bonesRuleSoft))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dose row (expanded list)

private struct DewormingDoseRow: View {
    let dew: Deworming
    let isNext: Bool
    var allDewormings: [Deworming]

    var body: some View {
        let isOverdue = !dew.isCompleted && dew.date < Date()
        let numbers = DoseSeries.parseDoseNumbers(from: dew.notes ?? "")

        let primaryLabel: String = {
            if let cur = numbers.current {
                if let tot = numbers.total { return "Dosis \(cur)/\(tot)" }
                return "Dosis \(cur)"
            }
            let raw = (dew.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { return "Desparasitación" }
            let base = DoseSeries.splitDoseBase(from: raw)
            return base.prefix(1).uppercased() + base.dropFirst()
        }()

        HStack(spacing: 12) {
            Group {
                if dew.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bonesOk)
                } else if isOverdue {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.bonesOverdue)
                } else if isNext {
                    Image(systemName: "circle.fill").foregroundStyle(Color.bonesDeworming)
                } else {
                    Image(systemName: "circle").foregroundStyle(Color.bonesInkFaint)
                }
            }
            .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(primaryLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOverdue ? Color.bonesOverdue : Color.bonesInk)
                    if isOverdue {
                        DewStatusTag(label: "Vencida", color: .bonesOverdue)
                    } else if isNext {
                        DewStatusTag(label: "Próxima", color: .bonesDeworming)
                    }
                }
                Text(dew.date, format: .dateTime.day().month().year())
                    .font(.caption2).foregroundStyle(Color.bonesInkFaint)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct DewStatusTag: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.10)))
    }
}

// MARK: - Helpers de borrado en serie

private extension PetDewormingTab {
    func startDelete(for dew: Deworming) {
        let count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
        if count == 0 {
            deleteSingle(dew)
        } else {
            pendingDelete = dew
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }

    func deleteSingle(_ dew: Deworming) {
        NotificationManager.shared.cancelNotification(id: dew.id)
        context.delete(dew)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }

    func deleteThisAndFuture() {
        guard let dew = pendingDelete else { return }
        let all = DoseSeries.futureDewormings(from: dew, in: context)
        for d in all {
            NotificationManager.shared.cancelNotification(id: d.id)
            context.delete(d)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearPending()
    }

    func clearPending() {
        pendingFutureCount = 0
        pendingDelete = nil
        showingDeleteDialog = false
    }

    func startDeleteSeries(_ summary: PetDetailViewModel.DewormingSeriesSummary) {
        pendingSeriesItems = summary.items
        pendingSeriesCount = summary.items.count
        showingSeriesDeleteDialog = true
    }

    func deleteSeries() {
        for dew in pendingSeriesItems {
            NotificationManager.shared.cancelNotification(id: dew.id)
            context.delete(dew)
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        clearSeriesPending()
    }

    func clearSeriesPending() {
        pendingSeriesItems = []
        pendingSeriesCount = 0
        showingSeriesDeleteDialog = false
    }
}

// MARK: - Resumen de series de desparasitación

private extension PetDetailViewModel {
    enum DewormingSeriesStatus: Equatable {
        case notStarted
        case inProgress(current: Int, total: Int?)
        case completed
        case recurring(months: Int?, nextDate: Date?)
    }

    struct DewormingSeriesSummary: Identifiable {
        let id = UUID()
        let baseName: String
        let items: [Deworming]
        let lastCompleted: Deworming?
        let nextPending: Deworming?
        let status: DewormingSeriesStatus
        let overdueDays: Int?
    }

    var dewormingSeriesSummaries: [DewormingSeriesSummary] {
        let all = dewormings.sorted { $0.date < $1.date }
        let groups: [String: [Deworming]] = Dictionary(grouping: all) { d in
            if let sid = d.seriesID { return "sid:\(sid.uuidString)" }
            if let rule = d.rrule, !rule.isEmpty { return "rrule:\(rule)" }
            return "notes:\(DoseSeries.normalizeNotes(d.notes))"
        }
        let now = Date()

        func daysBetween(_ from: Date, _ to: Date) -> Int {
            let comps = Calendar.current.dateComponents([.day], from: from, to: to)
            return abs(comps.day ?? 0)
        }

        func displayBase(from notes: String?) -> String {
            let raw = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { return "Desparasitación" }
            let base = DoseSeries.splitDoseBase(from: raw)
            return base.prefix(1).uppercased() + base.dropFirst()
        }

        return groups.values.compactMap { arr in
            let items = arr.sorted { $0.date < $1.date }
            guard let first = items.first else { return nil }
            let baseName = displayBase(from: first.notes)
            let lastCompleted = items.filter { $0.isCompleted }.max(by: { $0.date < $1.date })

            let nextPendingFuture = items
                .filter { !$0.isCompleted && $0.date >= now }
                .min(by: { $0.date < $1.date })
            let pendingPast = items
                .filter { !$0.isCompleted && $0.date < now }
                .sorted { $0.date < $1.date }

            let selectedNext: Deworming? = pendingPast.first ?? nextPendingFuture

            let overdueDays: Int? = {
                guard let next = selectedNext, next.date < now else { return nil }
                return daysBetween(next.date, now)
            }()

            let totals = items.compactMap { DoseSeries.parseDoseNumbers(from: $0.notes ?? "").total }
            let totalExpected = totals.max()
            let completedCountByLabel = items
                .filter { $0.isCompleted }
                .compactMap { DoseSeries.parseDoseNumbers(from: $0.notes ?? "").current }
                .max() ?? 0
            let completedCountFallback = items.filter { $0.isCompleted }.count
            let completedCount = max(completedCountByLabel, completedCountFallback)

            var recurringMonths: Int? = nil
            if items.count >= 2 {
                let sorted = items.sorted { $0.date < $1.date }
                for i in 1..<sorted.count {
                    let interval = sorted[i].date.timeIntervalSince(sorted[i-1].date) / (24 * 3600)
                    let months = Int((interval / 30.0).rounded())
                    if [3, 6].contains(months) {
                        recurringMonths = months
                        break
                    }
                }
            }

            let status: DewormingSeriesStatus = {
                if let total = totalExpected, completedCount >= total, recurringMonths == nil {
                    return .completed
                }
                if let next = selectedNext {
                    if let m = recurringMonths {
                        return .recurring(months: m, nextDate: next.date)
                    } else {
                        return .inProgress(current: max(1, completedCount + 1), total: totalExpected)
                    }
                }
                if completedCount == 0 { return .notStarted }
                if let total = totalExpected, completedCount < total {
                    return .inProgress(current: max(1, completedCount + 1), total: total)
                }
                if let m = recurringMonths { return .recurring(months: m, nextDate: nil) }
                return .completed
            }()

            return DewormingSeriesSummary(
                baseName: baseName,
                items: items,
                lastCompleted: lastCompleted,
                nextPending: selectedNext,
                status: status,
                overdueDays: overdueDays
            )
        }
        .sorted { $0.baseName.lowercased() < $1.baseName.lowercased() }
    }
}

// MARK: - Previews

#Preview("Desparasitación – Series típicas (CO)") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.seedCommonColombia(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Desparasitación – Vacío") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.emptyPet(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Desparasitación – Expandido (auto)") {
    let container = DewPreviewData.makeContainer()
    let pet = DewPreviewData.seedCommonColombia(in: container)
    return PetDewormingTabPreviewHost(pet: pet)
        .modelContainer(container)
}

private struct PetDewormingTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel

    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }

    var body: some View {
        PetDewormingTab(viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

private enum DewPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Pet.self, Vaccine.self, Deworming.self, WeightEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }

    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }

    @discardableResult
    static func seedCommonColombia(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)

        let cal = Calendar.current
        let now = Date()

        let seriesDrontal = UUID()
        let dr1 = Deworming(date: now, pet: pet, notes: "Drontal Plus (dosis 1/2)",
                            prescriptionImageData: nil, seriesID: seriesDrontal)
        let dr2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: pet, notes: "Drontal Plus (dosis 2/2)",
                            prescriptionImageData: nil, seriesID: seriesDrontal)
        let drBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                  pet: pet, notes: "Drontal Plus",
                                  prescriptionImageData: nil, seriesID: seriesDrontal)
        dr1.isCompleted = true

        let seriesEndogard = UUID()
        let en1 = Deworming(date: cal.date(byAdding: .day, value: -10, to: now)!,
                            pet: pet, notes: "Endogard (dosis 1/2)",
                            prescriptionImageData: nil, seriesID: seriesEndogard)
        let en2 = Deworming(date: cal.date(byAdding: .day, value: 5, to: now)!,
                            pet: pet, notes: "Endogard (dosis 2/2)",
                            prescriptionImageData: nil, seriesID: seriesEndogard)
        let enBooster = Deworming(date: cal.date(byAdding: .month, value: 3, to: now)!,
                                  pet: pet, notes: "Endogard",
                                  prescriptionImageData: nil, seriesID: seriesEndogard)

        let seriesPanacur = UUID()
        let p1 = Deworming(date: cal.date(byAdding: .day, value: -1, to: now)!,
                           pet: pet, notes: "Panacur (dosis 1/3)",
                           prescriptionImageData: nil, seriesID: seriesPanacur)
        let p2 = Deworming(date: now, pet: pet, notes: "Panacur (dosis 2/3)",
                           prescriptionImageData: nil, seriesID: seriesPanacur)
        let p3 = Deworming(date: cal.date(byAdding: .day, value: 1, to: now)!,
                           pet: pet, notes: "Panacur (dosis 3/3)",
                           prescriptionImageData: nil, seriesID: seriesPanacur)
        let pR1 = Deworming(date: cal.date(byAdding: .day, value: 14, to: now)!,
                            pet: pet, notes: "Panacur (dosis 1/3)",
                            prescriptionImageData: nil, seriesID: seriesPanacur)
        let pR2 = Deworming(date: cal.date(byAdding: .day, value: 15, to: now)!,
                            pet: pet, notes: "Panacur (dosis 2/3)",
                            prescriptionImageData: nil, seriesID: seriesPanacur)
        let pR3 = Deworming(date: cal.date(byAdding: .day, value: 16, to: now)!,
                            pet: pet, notes: "Panacur (dosis 3/3)",
                            prescriptionImageData: nil, seriesID: seriesPanacur)
        p1.isCompleted = true

        let seriesMilbemax = UUID()
        let mi1 = Deworming(date: cal.date(byAdding: .day, value: -30, to: now)!,
                            pet: pet, notes: "Milbemax",
                            prescriptionImageData: nil, seriesID: seriesMilbemax)
        mi1.isCompleted = true
        let mi2 = Deworming(date: now, pet: pet, notes: "Milbemax",
                            prescriptionImageData: nil, seriesID: seriesMilbemax)
        let miNext = Deworming(date: cal.date(byAdding: .month, value: 6, to: now)!,
                               pet: pet, notes: "Milbemax",
                               prescriptionImageData: nil, seriesID: seriesMilbemax)

        [dr1, dr2, drBooster, en1, en2, enBooster,
         p1, p2, p3, pR1, pR2, pR3, mi1, mi2, miNext].forEach { ctx.insert($0) }

        try? ctx.save()
        return pet
    }
}

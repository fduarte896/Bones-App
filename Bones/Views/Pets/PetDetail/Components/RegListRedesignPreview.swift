//
//  RegListRedesignPreview.swift
//  Bones
//
//  DESIGN EXPLORATION — archivo solo de preview, no modifica vistas de producción.
//  Explora un rediseño de la lista de vacunas / desparasitación:
//  - Card por serie (sin List, sin Section header forzado)
//  - Timeline visual de dosis siempre visible
//  - Un solo nivel de expansión (sin sub-secciones anidadas)
//

import SwiftUI

// MARK: - Mock data (sin SwiftData)

private struct MockDose: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let isCompleted: Bool

    var isOverdue: Bool { !isCompleted && date < Date() }
}

private struct MockSeries: Identifiable {
    let id = UUID()
    let name: String
    let doses: [MockDose]

    var status: HealthStatus {
        let now = Date()
        if doses.contains(where: { !$0.isCompleted && $0.date < now }) { return .overdue }
        if let next = nextPending?.date, next.timeIntervalSince(now) < 7 * 86_400 { return .soon }
        return .ok
    }

    var nextPending: MockDose? {
        let now = Date()
        // Prioriza la vencida más antigua; si no hay, la futura más próxima
        return doses.filter { !$0.isCompleted && $0.date < now }.min(by: { $0.date < $1.date })
            ?? doses.filter { !$0.isCompleted }.min(by: { $0.date < $1.date })
    }

    var lastCompleted: MockDose? {
        doses.filter(\.isCompleted).max(by: { $0.date < $1.date })
    }

    var overdueDays: Int? {
        guard let next = nextPending, next.isOverdue else { return nil }
        return Calendar.current.dateComponents([.day], from: next.date, to: Date()).day.map { abs($0) }
    }

    var sortedDoses: [MockDose] { doses.sorted { $0.date < $1.date } }
}

// MARK: - Dose timeline

private struct DoseTimeline: View {
    let doses: [MockDose]
    let nextPendingID: UUID?
    let accent: Color
    private let maxVisible = 8

    private var visible: [MockDose] { Array(doses.prefix(maxVisible)) }
    private var overflow: Int { max(0, doses.count - maxVisible) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { idx, dose in
                if idx > 0 {
                    connectorLine(before: visible[idx - 1])
                }
                DoseDot(dose: dose, isNext: dose.id == nextPendingID, accent: accent)
            }
            if overflow > 0 {
                Rectangle()
                    .fill(Color.bonesRule)
                    .frame(width: 12, height: 2)
                Text("+\(overflow)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.bonesInkFaint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.bonesRule))
            }
        }
    }

    private func connectorLine(before: MockDose) -> some View {
        let color: Color = before.isCompleted ? Color.bonesOk.opacity(0.35)
            : before.isOverdue ? Color.bonesOverdue.opacity(0.25)
            : Color.bonesRule
        return Rectangle().fill(color).frame(width: 16, height: 2)
    }
}

private struct DoseDot: View {
    let dose: MockDose
    let isNext: Bool
    let accent: Color

    var body: some View {
        ZStack {
            if dose.isCompleted {
                Circle().fill(Color.bonesOk)
            } else if dose.isOverdue {
                Circle().fill(Color.bonesOverdue)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
            } else if isNext {
                Circle().fill(accent)
                Circle().strokeBorder(accent.opacity(0.3), lineWidth: 3)
                    .padding(-3)
            } else {
                Circle().strokeBorder(Color.bonesInkFaint, lineWidth: 1.5)
                    .background(Circle().fill(Color.bonesBg))
            }
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Dose row (lista expandida)

private struct DoseRow: View {
    let dose: MockDose
    let isNext: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if dose.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bonesOk)
                } else if dose.isOverdue {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.bonesOverdue)
                } else if isNext {
                    Image(systemName: "circle.fill").foregroundStyle(accent)
                } else {
                    Image(systemName: "circle").foregroundStyle(Color.bonesInkFaint)
                }
            }
            .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(dose.label)
                    .font(.subheadline)
                    .foregroundStyle(dose.isOverdue ? Color.bonesOverdue : Color.bonesInk)
                Text(dose.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Color.bonesInkSoft)
            }

            Spacer()

            if dose.isOverdue {
                Text("Vencida")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.bonesOverdue)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.bonesOverdue.opacity(0.10)))
            } else if isNext && !dose.isCompleted {
                Text("Próxima")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.10)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Series card

private struct SeriesCard: View {
    let series: MockSeries
    let accent: Color
    var initiallyExpanded: Bool = false
    @State private var expanded: Bool

    init(series: MockSeries, accent: Color, initiallyExpanded: Bool = false) {
        self.series = series
        self.accent = accent
        self.initiallyExpanded = initiallyExpanded
        _expanded = State(initialValue: initiallyExpanded)
    }

    private var nextLabel: String {
        guard let next = series.nextPending else { return "Sin próxima" }
        if let days = series.overdueDays { return "Hace \(days) día\(days == 1 ? "" : "s")" }
        let now = Date()
        if Calendar.current.isDateInToday(next.date) { return "hoy" }
        if Calendar.current.isDateInTomorrow(next.date) { return "mañana" }
        if next.date.timeIntervalSince(now) < 7 * 86_400 { return bonesRelativeLabel(for: next.date) }
        return bonesShortDate(next.date)
    }

    private var nextLabelColor: Color {
        switch series.status {
        case .overdue: return .bonesOverdue
        case .soon:    return .bonesSoon
        case .ok:      return .bonesInk
        }
    }

    private var statusLabel: String {
        switch series.status {
        case .overdue:
            if let d = series.overdueDays { return "Hace \(d) d" }
            return "Vencida"
        case .soon:
            if let next = series.nextPending { return bonesRelativeLabel(for: next.date) }
            return "Próxima"
        case .ok:
            if let next = series.nextPending { return bonesShortDate(next.date) }
            return "Al día"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (siempre visible) ──────────────────────
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    expanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    // Nombre + estado
                    HStack(spacing: 8) {
                        Text(series.name)
                            .font(.headline)
                            .foregroundStyle(Color.bonesInk)
                        StatusPill(status: series.status, label: statusLabel)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.bonesInkFaint)
                            .rotationEffect(expanded ? .degrees(180) : .zero)
                    }

                    // Timeline de dosis
                    DoseTimeline(
                        doses: series.sortedDoses,
                        nextPendingID: series.nextPending?.id,
                        accent: accent
                    )

                    // Métricas
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Siguiente")
                                .font(.caption2)
                                .foregroundStyle(Color.bonesInkFaint)
                            Text(nextLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(nextLabelColor)
                        }

                        if let last = series.lastCompleted {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Última")
                                    .font(.caption2)
                                    .foregroundStyle(Color.bonesInkFaint)
                                Text(last.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.bonesInkSoft)
                            }
                        }

                        Spacer()

                        let completed = series.doses.filter(\.isCompleted).count
                        let total = series.doses.count
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Dosis")
                                .font(.caption2)
                                .foregroundStyle(Color.bonesInkFaint)
                            Text("\(completed)/\(total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Color.bonesInkSoft)
                        }
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Lista expandida ───────────────────────────────
            if expanded {
                Divider().padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(series.sortedDoses.enumerated()), id: \.element.id) { idx, dose in
                        DoseRow(
                            dose: dose,
                            isNext: dose.id == series.nextPending?.id,
                            accent: accent
                        )
                        if idx < series.sortedDoses.count - 1 {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.bonesPanel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Lista completa (contenedor de exploración)

private struct RegListRedesign: View {
    let title: String
    let icon: String
    let accent: Color
    let series: [MockSeries]

    var body: some View {
        NavigationStack {
            Group {
                if series.isEmpty {
                    ContentUnavailableView(
                        "Sin registros",
                        systemImage: icon,
                        description: Text("Agrega el primero con el botón +")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedSeries) { s in
                                SeriesCard(
                                    series: s,
                                    accent: accent,
                                    initiallyExpanded: s.status == .overdue
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.bonesBg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {}) { Image(systemName: "plus") }
                }
            }
        }
    }

    private var sortedSeries: [MockSeries] {
        series.sorted { a, b in
            if a.status == .overdue, b.status != .overdue { return true }
            if b.status == .overdue, a.status != .overdue { return false }
            return (a.nextPending?.date ?? .distantFuture) < (b.nextPending?.date ?? .distantFuture)
        }
    }
}

// MARK: - Mock data builders

private func mockDose(_ label: String, daysFromNow: Int, completed: Bool = false) -> MockDose {
    MockDose(
        label: label,
        date: Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!,
        isCompleted: completed
    )
}

private let vaccineSeriesMock: [MockSeries] = [
    MockSeries(name: "Antirrábica", doses: [
        mockDose("Dosis 1", daysFromNow: -730, completed: true),
        mockDose("Refuerzo anual", daysFromNow: -5),   // vencida
    ]),
    MockSeries(name: "Polivalente (DHPPi)", doses: [
        mockDose("Dosis 1/3", daysFromNow: -60, completed: true),
        mockDose("Dosis 2/3", daysFromNow: -30, completed: true),
        mockDose("Dosis 3/3", daysFromNow: 5),         // próxima (~soon)
    ]),
    MockSeries(name: "Leptospirosis", doses: [
        mockDose("Dosis única", daysFromNow: 25),
    ]),
    MockSeries(name: "Moquillo", doses: [
        mockDose("Dosis 1/2", daysFromNow: -180, completed: true),
        mockDose("Dosis 2/2", daysFromNow: -90, completed: true),
        mockDose("Refuerzo 1", daysFromNow: 90),
        mockDose("Refuerzo 2", daysFromNow: 455),
    ]),
]

private let dewormingSeriesMock: [MockSeries] = [
    MockSeries(name: "Drontal Plus", doses: [
        mockDose("Dosis 1/2", daysFromNow: -30, completed: true),
        mockDose("Dosis 2/2", daysFromNow: -15, completed: true),
        mockDose("Refuerzo", daysFromNow: 60),
    ]),
    MockSeries(name: "Endogard", doses: [
        mockDose("Dosis 1/2", daysFromNow: -10),       // vencida
        mockDose("Dosis 2/2", daysFromNow: 5),
        mockDose("Próximo ciclo", daysFromNow: 80),
    ]),
    MockSeries(name: "Panacur", doses: [
        mockDose("Ciclo 1 – Dosis 1/3", daysFromNow: -1, completed: true),
        mockDose("Ciclo 1 – Dosis 2/3", daysFromNow: 1),
        mockDose("Ciclo 1 – Dosis 3/3", daysFromNow: 2),
        mockDose("Ciclo 2 – Dosis 1/3", daysFromNow: 14),
        mockDose("Ciclo 2 – Dosis 2/3", daysFromNow: 15),
        mockDose("Ciclo 2 – Dosis 3/3", daysFromNow: 16),
    ]),
    MockSeries(name: "Milbemax", doses: [
        mockDose("Aplicación", daysFromNow: -180, completed: true),
        mockDose("Aplicación", daysFromNow: -2),       // vencida
        mockDose("Próxima", daysFromNow: 185),
    ]),
]

// MARK: - Previews

#Preview("Vacunas – Rediseño") {
    RegListRedesign(
        title: "Vacunas",
        icon: "syringe",
        accent: .bonesVaccine,
        series: vaccineSeriesMock
    )
}

#Preview("Desparasitación – Rediseño") {
    RegListRedesign(
        title: "Desparasitación",
        icon: "ladybug.fill",
        accent: .bonesDeworming,
        series: dewormingSeriesMock
    )
}

#Preview("Lista vacía") {
    RegListRedesign(
        title: "Vacunas",
        icon: "syringe",
        accent: .bonesVaccine,
        series: []
    )
}

#Preview("Serie única – al día") {
    RegListRedesign(
        title: "Vacunas",
        icon: "syringe",
        accent: .bonesVaccine,
        series: [
            MockSeries(name: "Rabia", doses: [
                mockDose("Dosis 1", daysFromNow: -365, completed: true),
                mockDose("Refuerzo anual", daysFromNow: 45),
            ]),
        ]
    )
}

#Preview("Solo vencidas") {
    RegListRedesign(
        title: "Desparasitación",
        icon: "ladybug.fill",
        accent: .bonesDeworming,
        series: [
            MockSeries(name: "Drontal Plus", doses: [
                mockDose("Dosis 1/2", daysFromNow: -45),
                mockDose("Dosis 2/2", daysFromNow: -30),
            ]),
            MockSeries(name: "Milbemax", doses: [
                mockDose("Aplicación", daysFromNow: -8),
            ]),
        ]
    )
}

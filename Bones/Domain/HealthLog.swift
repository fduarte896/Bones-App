import Foundation
import SwiftData

/// Escribe en el historial de una mascota y mantiene al día la próxima fecha.
@MainActor
struct HealthLog {
    let context: ModelContext
    var calendar: Calendar = .current

    @discardableResult
    func saveVaccine(_ draft: RecordDraft, for pet: Pet, editing existing: Vaccine? = nil,
                     now: Date = .now) throws -> Vaccine {
        let name = draft.name.nilIfBlank ?? "Vacuna"
        let changes = Changes(existing: existing, draft: draft, calendar: calendar)

        let record = existing ?? Vaccine(date: draft.date, pet: pet, vaccineName: name)
        if existing == nil { context.insert(record) }
        record.vaccineName = name
        record.manufacturer = draft.manufacturer.nilIfBlank
        apply(draft, to: record, now: now)

        let kind = record.careKind
        let siblings = pet.vaccines.filter { $0.id != record.id && $0.careKind == kind }
        settle(record, siblings: siblings, reschedule: changes.affectSchedule) { date in
            Vaccine(date: date, pet: pet, vaccineName: name, manufacturer: record.manufacturer)
        }
        try context.save()
        return record
    }

    @discardableResult
    func saveDeworming(_ draft: RecordDraft, for pet: Pet, editing existing: Deworming? = nil,
                       now: Date = .now) throws -> Deworming {
        let product = draft.name.nilIfBlank ?? ""
        let changes = Changes(existing: existing, draft: draft, calendar: calendar)

        let record = existing ?? Deworming(date: draft.date, pet: pet)
        if existing == nil { context.insert(record) }
        record.kind = draft.dewormingKind
        record.productName = product
        apply(draft, to: record, now: now)

        let siblings = pet.dewormings.filter { $0.id != record.id && $0.kind == record.kind }
        settle(record, siblings: siblings, reschedule: changes.affectSchedule) { date in
            Deworming(date: date, pet: pet, kind: record.kind, productName: product)
        }
        try context.save()
        return record
    }

    @discardableResult
    func saveWeight(_ draft: RecordDraft, for pet: Pet, editing existing: WeightEntry? = nil) throws -> WeightEntry {
        let kg = draft.weightKg ?? 0
        let record = existing ?? WeightEntry(date: draft.date, pet: pet, weightKg: kg)
        if existing == nil { context.insert(record) }
        record.date = draft.date
        record.weightKg = kg
        record.notes = draft.notes.nilIfBlank
        try context.save()
        return record
    }

    func delete(_ record: some PersistentModel) throws {
        context.delete(record)
        try context.save()
    }

    // MARK: - Internals

    private struct Changes {
        /// Si el guardado puede mover la próxima fecha: registro nuevo, uno programado
        /// que pasa a aplicado, o un cambio de fecha o de repetición.
        let affectSchedule: Bool

        init(existing: (some HealthRecord)?, draft: RecordDraft, calendar: Calendar) {
            guard let existing else {
                affectSchedule = true
                return
            }
            affectSchedule = !existing.isCompleted
                || !calendar.isDate(existing.date, inSameDayAs: draft.date)
                || existing.repeatRule != draft.repeatRule
        }
    }

    private func apply(_ draft: RecordDraft, to record: some HealthRecord, now: Date) {
        let planned = draft.isPlanned(now: now, calendar: calendar)
        record.date = draft.date
        record.notes = draft.notes.nilIfBlank
        record.prescriptionImageData = draft.photoData
        record.repeatRule = draft.repeatRule
        record.isCompleted = !planned
        record.completedAt = planned ? nil : (record.completedAt ?? now)
    }

    /// Después de registrar una aplicación, deja una sola "próxima vez" coherente con ella.
    ///
    /// Solo actúa si el registro es la aplicación más reciente: corregir una entrada
    /// antigua del historial no debe mover la próxima fecha.
    private func settle<Record: HealthRecord>(
        _ record: Record,
        siblings: [Record],
        reschedule: Bool,
        makeNext: (Date) -> Record
    ) {
        guard reschedule, record.isCompleted else { return }
        guard !siblings.contains(where: { $0.isCompleted && $0.date > record.date }) else { return }

        let pending = siblings.filter { !$0.isCompleted }
        if let rule = record.repeatRule {
            pending.forEach(context.delete)
            let next = makeNext(rule.next(after: record.date, calendar: calendar))
            next.repeatRule = rule
            context.insert(next)
        } else {
            // Sin repetición: lo que estaba programado hasta dentro de poco queda cumplido.
            let cutoff = CareStatus.soonWindowDays
            for planned in pending
            where DayMath.days(from: record.date, to: planned.date, calendar: calendar) <= cutoff {
                context.delete(planned)
            }
        }
    }
}

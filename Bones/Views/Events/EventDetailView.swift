//  EventDetailView.swift
//  Bones

import SwiftUI
import SwiftData

struct EventDetailView: View {
    let event: any BasicEvent
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    
    // Borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    
    var body: some View {
        Group {
            switch event {
            case let med as Medication:
                MedicationDetailView(med: med, isEditing: $isEditing) {
                    startDelete(for: med)
                }
            case let vac as Vaccine:
                VaccineDetailView(vac: vac, isEditing: $isEditing) {
                    startDelete(for: vac)
                }
            case let dew as Deworming:
                DewormingDetailView(dew: dew, isEditing: $isEditing) {
                    startDelete(for: dew)
                }
            case let groom as Grooming:
                GroomingDetailView(groom: groom, isEditing: $isEditing) {
                    deleteSingle(event: groom)
                }
            case let weight as WeightEntry:
                WeightEntryDetailView(weight: weight, isEditing: $isEditing) {
                    deleteSingle(event: weight)
                }
            default:
                Text("Tipo de evento no soportado.")
            }
        }
        .navigationTitle(event.displayType.isEmpty ? "Detalle" : event.displayType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(event.isCompleted ? "Desmarcar" : "Completar") {
                    toggleCompleted()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Guardar" : "Editar") {
                    if isEditing { saveAndReschedule() }
                    isEditing.toggle()
                }
            }
        }
        // Confirmación de borrado en serie cuando aplique
        .confirmationDialog(
            "¿Eliminar también futuras dosis?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            if pendingFutureCount > 0 {
                Button("Eliminar esta y \(pendingFutureCount) futuras", role: .destructive) {
                    deleteThisAndFuture()
                }
                Button("Eliminar solo esta", role: .destructive) {
                    deleteSingle(event: event)
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    deleteSingle(event: event)
                }
            }
            Button("Cancelar", role: .cancel) { clearPending() }
        } message: {
            if pendingFutureCount > 0 {
                Text("Se encontraron \(pendingFutureCount) dosis futuras relacionadas. ¿Deseas borrarlas también?")
            } else {
                Text("Esta acción no se puede deshacer.")
            }
        }
    }
}

// MARK: - Toolbar actions
private extension EventDetailView {
    func toggleCompleted() {
        event.isCompleted.toggle()
        event.completedAt = event.isCompleted ? Date() : nil
        NotificationManager.shared.cancelNotification(id: event.id)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
    
    func saveAndReschedule() {
        // Reprograma la notificación para la fecha actual del evento
        NotificationManager.shared.cancelNotification(id: event.id)
        let title = event.displayType.isEmpty ? "Evento" : event.displayType
        let body = "\(event.pet?.name ?? "") – \(event.displayName)"
        NotificationManager.shared.scheduleNotification(
            id: event.id, title: title, body: body, fireDate: event.date, advance: 0
        )
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - Delete helpers
private extension EventDetailView {
    func deleteSingle(event: any BasicEvent) {
        NotificationManager.shared.cancelNotification(id: event.id)
        context.delete(event)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        dismiss()
    }
    
    func startDelete(for med: Medication) {
        let count = max(0, futureMedications(from: med).count - 1)
        if count == 0 {
            deleteSingle(event: med)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    func startDelete(for vac: Vaccine) {
        let count = max(0, futureVaccines(from: vac).count - 1)
        if count == 0 {
            deleteSingle(event: vac)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    func startDelete(for dew: Deworming) {
        let count = max(0, futureDewormings(from: dew).count - 1)
        if count == 0 {
            deleteSingle(event: dew)
        } else {
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    func deleteThisAndFuture() {
        switch event {
        case let med as Medication:
            for m in futureMedications(from: med) {
                NotificationManager.shared.cancelNotification(id: m.id)
                context.delete(m)
            }
        case let vac as Vaccine:
            for v in futureVaccines(from: vac) {
                NotificationManager.shared.cancelNotification(id: v.id)
                context.delete(v)
            }
        case let dew as Deworming:
            for d in futureDewormings(from: dew) {
                NotificationManager.shared.cancelNotification(id: d.id)
                context.delete(d)
            }
        default:
            break
        }
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        clearPending()
        dismiss()
    }
    
    func clearPending() {
        pendingFutureCount = 0
        showingDeleteDialog = false
    }
}

// MARK: - Future series helpers (mismo criterio que la lista)
private extension EventDetailView {
    func futureMedications(from med: Medication) -> [Medication] {
        guard let petID = med.pet?.id else { return [med] }
        let base = splitDose(from: med.name).base
        let start = med.date
        let predicate = #Predicate<Medication> { m in
            m.pet?.id == petID && m.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        return fetched.filter { splitDose(from: $0.name).base == base }
    }
    
    func futureVaccines(from vac: Vaccine) -> [Vaccine] {
        guard let petID = vac.pet?.id else { return [vac] }
        let base = splitDose(from: vac.vaccineName).base
        let start = vac.date
        let predicate = #Predicate<Vaccine> { v in
            v.pet?.id == petID && v.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: predicate))) ?? []
        return fetched.filter { splitDose(from: $0.vaccineName).base == base }
    }
    
    func futureDewormings(from dew: Deworming) -> [Deworming] {
        guard let petID = dew.pet?.id else { return [dew] }
        func norm(_ s: String?) -> String {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let baseNotes = norm(dew.notes)
        let start = dew.date
        let predicate = #Predicate<Deworming> { d in
            d.pet?.id == petID && d.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))) ?? []
        return fetched.filter { norm($0.notes) == baseNotes }
    }
    
    // split de " (dosis X/Y)" al final
    func splitDose(from name: String) -> (base: String, dose: String?) {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1)
        let closingParenIndex = name.index(before: name.endIndex)
        guard closingParenIndex > openParenIndex else { return (name, nil) }
        let contentStart = name.index(after: openParenIndex)
        let inside = String(name[contentStart..<closingParenIndex])
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
}

// MARK: - Sub‑vistas tipadas

private struct MedicationDetailView: View {
    @Bindable var med: Medication
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    
    var body: some View {
        Form {
            Header(pet: med.pet, title: med.name, icon: "pills.fill", isCompleted: med.isCompleted, date: med.date)
            
            Section("Información") {
                TextField("Nombre", text: $med.name)
                    .disabled(!isEditing)
                TextField("Dosis", text: $med.dosage)
                    .disabled(!isEditing)
                TextField("Frecuencia", text: $med.frequency)
                    .disabled(!isEditing)
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $med.date,
                           displayedComponents: [.date, .hourAndMinute])
                .disabled(!isEditing)
            }
            
            Section("Notas") {
                TextEditor(text: Binding($med.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .disabled(!isEditing)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
}

private struct VaccineDetailView: View {
    @Bindable var vac: Vaccine
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    
    var body: some View {
        Form {
            Header(pet: vac.pet, title: vac.vaccineName, icon: "syringe", isCompleted: vac.isCompleted, date: vac.date)
            
            Section("Información") {
                TextField("Nombre", text: $vac.vaccineName)
                    .disabled(!isEditing)
                TextField("Fabricante", text: Binding($vac.manufacturer, replacingNilWith: ""))
                    .disabled(!isEditing)
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $vac.date,
                           displayedComponents: [.date, .hourAndMinute])
                .disabled(!isEditing)
            }
            
            Section("Notas") {
                TextEditor(text: Binding($vac.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .disabled(!isEditing)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
}

private struct DewormingDetailView: View {
    @Bindable var dew: Deworming
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    
    var body: some View {
        Form {
            Header(pet: dew.pet, title: dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación", icon: "ladybug.fill", isCompleted: dew.isCompleted, date: dew.date)
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $dew.date,
                           displayedComponents: [.date, .hourAndMinute])
                .disabled(!isEditing)
            }
            
            Section("Notas") {
                TextEditor(text: Binding($dew.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .disabled(!isEditing)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
}

private struct GroomingDetailView: View {
    @Bindable var groom: Grooming
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    
    var body: some View {
        Form {
            Header(pet: groom.pet, title: groom.notes?.isEmpty == false ? groom.notes! : "Cita de grooming", icon: "scissors", isCompleted: groom.isCompleted, date: groom.date)
            
            Section("Información") {
                TextField("Lugar", text: Binding($groom.location, replacingNilWith: ""))
                    .disabled(!isEditing)
                TextField("Descripción", text: Binding($groom.notes, replacingNilWith: ""))
                    .disabled(!isEditing)
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $groom.date,
                           displayedComponents: [.date, .hourAndMinute])
                .disabled(!isEditing)
            }
            
            Section {
                Button("Eliminar evento", role: .destructive, action: onDelete)
            }
        }
    }
}

private struct WeightEntryDetailView: View {
    @Bindable var weight: WeightEntry
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    
    var body: some View {
        Form {
            Header(pet: weight.pet, title: String(format: "Peso: %.1f kg", weight.weightKg), icon: "scalemass", isCompleted: true, date: weight.date)
            
            Section("Medición") {
                TextField("Peso (kg)", value: $weight.weightKg, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .disabled(!isEditing)
            }
            
            Section("Fecha") {
                DatePicker("Tomado el",
                           selection: $weight.date,
                           displayedComponents: [.date, .hourAndMinute])
                .disabled(!isEditing)
            }
            
            Section("Notas") {
                TextEditor(text: Binding($weight.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .disabled(!isEditing)
            }
            
            Section {
                Button("Eliminar registro", role: .destructive, action: onDelete)
            }
        }
    }
}

// MARK: - Pequeños helpers UI

private struct Header: View {
    let pet: Pet?
    let title: String
    let icon: String
    let isCompleted: Bool
    let date: Date
    
    var body: some View {
        HStack(spacing: 12) {
            if let data = pet?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "pawprint"))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(isCompleted ? "Completado" : "Pendiente")
                        .foregroundStyle(isCompleted ? .green : .orange)
                    Text(date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pet {
                    Text("🐾 \(pet.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Binding helpers para opcionales
private extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith placeholder: String) {
        self.init(
            get: { source.wrappedValue ?? "" },
            set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue }
        )
    }
}


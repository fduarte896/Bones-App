//  EventDetailView.swift
//  Bones

import SwiftUI
import SwiftData
import PhotosUI

struct EventDetailView: View {
    let event: any BasicEvent
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // Borrado en serie
    @State private var pendingFutureCount = 0
    @State private var showingDeleteDialog = false
    
    var body: some View {
        Group {
            switch event {
            case let med as Medication:
                MedicationDetailView(med: med) {
                    startDelete(for: med)
                }
            case let vac as Vaccine:
                VaccineDetailView(vac: vac) {
                    startDelete(for: vac)
                }
            case let dew as Deworming:
                DewormingDetailView(dew: dew) {
                    startDelete(for: dew)
                }
            case let groom as Grooming:
                GroomingDetailView(groom: groom) {
                    deleteSingle(event: groom)
                }
            case let weight as WeightEntry:
                WeightEntryDetailView(weight: weight) {
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
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: med.pet, title: med.name, icon: "pills.fill", isCompleted: med.isCompleted, date: med.date)
            
            Section("Información") {
                TextField("Nombre", text: $med.name)
                    .onChange(of: med.name) { _, _ in save() }
                TextField("Dosis", text: $med.dosage)
                    .onChange(of: med.dosage) { _, _ in save() }
                TextField("Frecuencia", text: $med.frequency)
                    .onChange(of: med.frequency) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $med.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: med.date) { _, _ in reschedule(for: med) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($med.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: med.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $med.prescriptionImageData) {
                // Propaga a toda la serie (pasado y futuro)
                let newData = med.prescriptionImageData
                propagatePrescriptionForMedication(med, with: newData, in: context)
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
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct VaccineDetailView: View {
    @Bindable var vac: Vaccine
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: vac.pet, title: vac.vaccineName, icon: "syringe", isCompleted: vac.isCompleted, date: vac.date)
            
            Section("Información") {
                TextField("Nombre", text: $vac.vaccineName)
                    .onChange(of: vac.vaccineName) { _, _ in save() }
                TextField("Fabricante", text: Binding($vac.manufacturer, replacingNilWith: ""))
                    .onChange(of: vac.manufacturer) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $vac.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: vac.date) { _, _ in reschedule(for: vac) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($vac.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: vac.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $vac.prescriptionImageData) {
                let newData = vac.prescriptionImageData
                propagatePrescriptionForVaccine(vac, with: newData, in: context)
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
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct DewormingDetailView: View {
    @Bindable var dew: Deworming
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: dew.pet, title: dew.notes?.isEmpty == false ? dew.notes! : "Desparasitación", icon: "ladybug.fill", isCompleted: dew.isCompleted, date: dew.date)
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $dew.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: dew.date) { _, _ in reschedule(for: dew) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($dew.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: dew.notes) { _, _ in save() }
            }
            
            PrescriptionSection(imageData: $dew.prescriptionImageData) {
                let newData = dew.prescriptionImageData
                propagatePrescriptionForDeworming(dew, with: newData, in: context)
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
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct GroomingDetailView: View {
    @Bindable var groom: Grooming
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: groom.pet, title: groom.notes?.isEmpty == false ? groom.notes! : "Cita de grooming", icon: "scissors", isCompleted: groom.isCompleted, date: groom.date)
            
            Section("Información") {
                TextField("Lugar", text: Binding($groom.location, replacingNilWith: ""))
                    .onChange(of: groom.location) { _, _ in save() }
                TextField("Descripción", text: Binding($groom.notes, replacingNilWith: ""))
                    .onChange(of: groom.notes) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Programado para",
                           selection: $groom.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: groom.date) { _, _ in reschedule(for: groom) }
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
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

private struct WeightEntryDetailView: View {
    @Bindable var weight: WeightEntry
    var onDelete: () -> Void
    @Environment(\.modelContext) private var context
    
    var body: some View {
        Form {
            Header(pet: weight.pet, title: String(format: "Peso: %.1f kg", weight.weightKg), icon: "scalemass", isCompleted: true, date: weight.date)
            
            Section("Medición") {
                TextField("Peso (kg)", value: $weight.weightKg, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .onChange(of: weight.weightKg) { _, _ in save() }
            }
            
            Section("Fecha") {
                DatePicker("Tomado el",
                           selection: $weight.date,
                           displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: weight.date) { _, _ in reschedule(for: weight) }
            }
            
            Section("Notas") {
                TextEditor(text: Binding($weight.notes, replacingNilWith: ""))
                    .frame(minHeight: 100)
                    .onChange(of: weight.notes) { _, _ in save() }
            }
            
            Section {
                Button("Eliminar registro", role: .destructive, action: onDelete)
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
        let body = "\(e.pet?.name ?? "") – \(e.displayName)"
        NotificationManager.shared.scheduleNotification(id: e.id, title: title, body: body, fireDate: e.date, advance: 0)
        save()
    }
}

// MARK: - Sección reutilizable de Prescripción

private struct PrescriptionSection: View {
    @Binding var imageData: Data?
    var onChange: () -> Void = {}
    
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingFullImage = false
    
    var body: some View {
        Section("Prescripción") {
            if let data = imageData, let ui = UIImage(data: data) {
                VStack(spacing: 8) {
                    Button {
                        showingFullImage = true
                    } label: {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                    HStack {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Reemplazar", systemImage: "photo")
                        }
                        
                        Button(role: .destructive) {
                            imageData = nil
                            onChange()
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        
                        Spacer()
                        
                        if let dataToShare = imageData {
                            ShareLink(item: dataToShare, preview: .init("Prescripción", image: Image(uiImage: ui)))
                        }
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                HStack {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                    
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Elegir de la fototeca", systemImage: "photo.on.rectangle")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.imageData = data
                        self.onChange()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(imageData: $imageData) {
                onChange()
            }
        }
        .fullScreenCover(isPresented: $showingFullImage) {
            if let data = imageData, let ui = UIImage(data: data) {
                ZoomableImageView(image: ui) {
                    showingFullImage = false
                }
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
private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith placeholder: String) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue }
        )
    }
}

// MARK: - Viewer con zoom para la imagen de prescripción
private struct ZoomableImageView: View {
    let image: UIImage
    var onClose: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture().onChanged { value in
                        scale = max(1.0, value)
                    })
                    .gesture(DragGesture().onChanged { value in
                        offset = value.translation
                    }.onEnded { _ in
                        if scale == 1 { offset = .zero }
                    })
                    .background(Color.black.opacity(0.98))
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }
}

// MARK: - Propagación a toda la serie

// Base del nombre sin sufijo " (dosis X/Y)"
private func splitDoseBase(from name: String) -> String {
    guard name.hasSuffix(")"),
          let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
        return name
    }
    let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    return base
}

private func propagatePrescriptionForMedication(_ med: Medication, with data: Data?, in context: ModelContext) {
    guard let petID = med.pet?.id else { return }
    let base = splitDoseBase(from: med.name)
    let predicate = #Predicate<Medication> { m in
        m.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
    let siblings = fetched.filter { splitDoseBase(from: $0.name) == base }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

private func propagatePrescriptionForVaccine(_ vac: Vaccine, with data: Data?, in context: ModelContext) {
    guard let petID = vac.pet?.id else { return }
    let base = splitDoseBase(from: vac.vaccineName)
    let predicate = #Predicate<Vaccine> { v in
        v.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: predicate))) ?? []
    let siblings = fetched.filter { splitDoseBase(from: $0.vaccineName) == base }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

private func propagatePrescriptionForDeworming(_ dew: Deworming, with data: Data?, in context: ModelContext) {
    guard let petID = dew.pet?.id else { return }
    func norm(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    let baseNotes = norm(dew.notes)
    let predicate = #Predicate<Deworming> { d in
        d.pet?.id == petID
    }
    let fetched = (try? context.fetch(FetchDescriptor<Deworming>(predicate: predicate))) ?? []
    let siblings = fetched.filter { norm($0.notes) == baseNotes }
    for s in siblings {
        s.prescriptionImageData = data
    }
    try? context.save()
    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
}

// MARK: - Previews (se mantienen igual que antes)

private enum EventDetailPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            Grooming.self,
            WeightEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}

#Preview("Detalle – Medicamento") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let med = Medication(date: Date().addingTimeInterval(3600),
                         pet: pet,
                         name: "Amoxicilina (dosis 1/3)",
                         dosage: "250 mg",
                         frequency: "cada 8 h",
                         notes: "Tomar con comida")
    ctx.insert(med)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: med)
    }
    .modelContainer(container)
}

#Preview("Detalle – Vacuna") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    
    let vac = Vaccine(date: Date().addingTimeInterval(24*3600),
                      pet: pet,
                      vaccineName: "Rabia (dosis 1/3)",
                      manufacturer: "VetLabs",
                      notes: "Primera dosis")
    ctx.insert(vac)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: vac)
    }
    .modelContainer(container)
}

#Preview("Detalle – Desparasitación") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let dew = Deworming(date: Date().addingTimeInterval(7*24*3600),
                        pet: pet,
                        notes: "Tableta mensual")
    ctx.insert(dew)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: dew)
    }
    .modelContainer(container)
}

#Preview("Detalle – Grooming") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
    ctx.insert(pet)
    
    let groom = Grooming(date: Date().addingTimeInterval(3*24*3600),
                         pet: pet,
                         location: "Pet Spa",
                         notes: "Baño y corte")
    ctx.insert(groom)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: groom)
    }
    .modelContainer(container)
}

#Preview("Detalle – Peso") {
    let container = EventDetailPreviewData.makeContainer()
    let ctx = ModelContext(container)
    
    let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
    ctx.insert(pet)
    
    let weight = WeightEntry(date: Date().addingTimeInterval(-2*24*3600),
                             pet: pet,
                             weightKg: 23.4,
                             notes: "Post entrenamiento")
    ctx.insert(weight)
    try? ctx.save()
    
    return NavigationStack {
        EventDetailView(event: weight)
    }
    .modelContainer(container)
}

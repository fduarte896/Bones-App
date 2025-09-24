//
//  EventsListView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData

// MARK: - Vista global de eventos
struct EventsListView: View {
    // 1. Contexto para el VM
    let context: ModelContext
    
    // 2. ViewModel
    @StateObject private var vm: EventsListViewModel
    
    // 3. Estados para Quick Add desde la vista global
    @State private var petForQuickAdd: Pet?
    @State private var showingPetChooser = false
    @State private var showNoPetsAlert = false
    @State private var showingAddPet = false

    // 4. Estados para borrado con confirmación (a nivel padre)
    @State private var pendingDeleteEvent: (any BasicEvent)?
    @State private var pendingFutureCount: Int = 0
    @State private var showingDeleteDialog = false
    
    // 5. Init para inyectar context → VM
    init(context: ModelContext) {
        self.context = context
        _vm = StateObject(wrappedValue: EventsListViewModel(context: context))
    }
    
    // 6. UI
    var body: some View {
        NavigationStack {
            List {
                if vm.sections.isEmpty {
                    ContentUnavailableView("Sin eventos próximos",
                                           systemImage: "calendar")
                } else {
                    ForEach(vm.sections) { section in
                        Section(section.title) {
                            ForEach(section.items, id: \.id) { event in
                                NavigationLink {
                                    EventDetailView(event: event)
                                } label: {
                                    EventRow(event: event)
                                }
                                // Swipe completar
                                .swipeActions(edge: .leading) {
                                    Button {
                                        vm.toggleCompleted(event)
                                    } label: { Label("Completar", systemImage: "checkmark") }
                                    .tint(.green)
                                }
                                // Swipe borrar → delega al padre (estable)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        startDelete(for: event)
                                    } label: { Label("Borrar", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Eventos")
            .toolbar {
                // Botón “+” para agregar evento
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startQuickAdd()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nuevo evento")
                }
                
                // Botón de filtros existente
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle("Mostrar completados", isOn: $vm.showPast)
                        // ----------------- Filtro por mascota -----------------
                        Section("Mascota") {
                            Picker("Mascota", selection: $vm.petFilter) {
                                // “Todas” (sin filtro)
                                Label("Todas", systemImage: "pawprint").tag(PetFilter.all)
                                // Generar una opción por cada mascota
                                ForEach(vm.allPets) { pet in
                                    Label(pet.name, systemImage: "pawprint.fill")
                                        .tag(PetFilter(id: pet.id, name: pet.name))
                                }
                            }
                            .pickerStyle(.inline)   // Muestra las filas directamente dentro del menú
                        }
                        
                        // ----------------- Filtro por tipo -----------------
                        Section("Tipo de evento") {
                            Picker("Tipo", selection: $vm.filter) {
                                ForEach(EventTypeFilter.allCases) {
                                    Label($0.rawValue, systemImage: $0.icon).tag($0)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    } label: {
                        // Icono único para los filtros
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { vm.fetchAllEvents() }  // pull-to-refresh
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            vm.fetchAllEvents()
        }
        // Hoja: elegir mascota si el filtro está en “Todas” y hay varias
        .sheet(isPresented: $showingPetChooser) {
            PetChooserSheet(pets: vm.allPets) { chosen in
                petForQuickAdd = chosen
            }
        }
        // Hoja: Quick Add (se presenta cuando ya tenemos mascota)
        .sheet(item: $petForQuickAdd) { pet in
            EventQuickAddSheet(pet: pet)
        }
        // Hoja: crear mascota si no hay ninguna
        .sheet(isPresented: $showingAddPet) {
            AddPetSheet()
        }
        // Alerta: no hay mascotas
        .alert("No hay mascotas", isPresented: $showNoPetsAlert) {
            Button("Crear mascota") { showingAddPet = true }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Primero crea una mascota para poder añadir eventos.")
        }
        // Diálogo de confirmación para borrado en serie (a nivel padre)
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
                    if let e = pendingDeleteEvent { vm.delete(e) }
                    clearPending()
                }
            } else {
                Button("Eliminar", role: .destructive) {
                    if let e = pendingDeleteEvent { vm.delete(e) }
                    clearPending()
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
    
    // MARK: - Lógica de arranque de Quick Add
    private func startQuickAdd() {
        // 1) ¿Hay una mascota filtrada?
        if let id = vm.petFilter.id,
           let pet = vm.allPets.first(where: { $0.id == id }) {
            petForQuickAdd = pet
            return
        }
        // 2) Filtro en “Todas”: decidir según cantidad de mascotas
        if vm.allPets.isEmpty {
            showNoPetsAlert = true
        } else if vm.allPets.count == 1 {
            petForQuickAdd = vm.allPets[0]
        } else {
            showingPetChooser = true
        }
    }
    
    // MARK: - Borrado con confirmación (a nivel padre)
    private func startDelete(for event: any BasicEvent) {
        // Calcula futuras según el tipo
        let count: Int
        switch event {
        case let med as Medication:
            count = max(0, futureMedications(from: med).count - 1)
        case let vac as Vaccine:
            count = max(0, futureVaccines(from: vac).count - 1)
        case let dew as Deworming:
            count = max(0, futureDewormings(from: dew).count - 1)
        default:
            // Otros tipos: borrar directo
            vm.delete(event)
            return
        }
        
        if count == 0 {
            vm.delete(event)
        } else {
            pendingDeleteEvent = event
            pendingFutureCount = count
            showingDeleteDialog = true
        }
    }
    
    private func deleteThisAndFuture() {
        guard let e = pendingDeleteEvent else { return }
        switch e {
        case let med as Medication:
            for m in futureMedications(from: med) {
                NotificationManager.shared.cancelNotification(id: m.id)
                context.delete(m)
            }
            try? context.save()
        case let vac as Vaccine:
            for v in futureVaccines(from: vac) {
                NotificationManager.shared.cancelNotification(id: v.id)
                context.delete(v)
            }
            try? context.save()
        case let dew as Deworming:
            for d in futureDewormings(from: dew) {
                NotificationManager.shared.cancelNotification(id: d.id)
                context.delete(d)
            }
            try? context.save()
        default:
            break
        }
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        vm.fetchAllEvents()
        clearPending()
    }
    
    private func clearPending() {
        pendingDeleteEvent = nil
        pendingFutureCount = 0
        showingDeleteDialog = false
    }
    
    // MARK: - Búsqueda de dosis futuras relacionadas (usa el context del padre)
    private func futureMedications(from med: Medication) -> [Medication] {
        guard let petID = med.pet?.id else { return [med] }
        let base = splitDose(from: med.name).base
        let start = med.date
        let predicate = #Predicate<Medication> { m in
            m.pet?.id == petID && m.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Medication>(predicate: predicate))) ?? []
        return fetched.filter { splitDose(from: $0.name).base == base }
    }
    
    private func futureVaccines(from vac: Vaccine) -> [Vaccine] {
        guard let petID = vac.pet?.id else { return [vac] }
        let base = splitDose(from: vac.vaccineName).base
        let start = vac.date
        let predicate = #Predicate<Vaccine> { v in
            v.pet?.id == petID && v.date >= start
        }
        let fetched = (try? context.fetch(FetchDescriptor<Vaccine>(predicate: predicate))) ?? []
        return fetched.filter { splitDose(from: $0.vaccineName).base == base }
    }
    
    private func futureDewormings(from dew: Deworming) -> [Deworming] {
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
    
    // Reutiliza el mismo separador de dosis que usas en la fila
    private func splitDose(from name: String) -> (base: String, dose: String?) {
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

// MARK: - Fila reutilizable (solo UI; los swipes están en el padre)
private struct EventRow: View {
    let event: any BasicEvent
    
    // Separa " (dosis X/Y)" del nombre para mostrar subtítulo
    private func splitDose(from name: String) -> (base: String, dose: String?) {
        guard name.hasSuffix(")"),
              let markerRange = name.range(of: " (dosis ", options: [.backwards]) else {
            return (name, nil)
        }
        let openParenIndex = name.index(markerRange.lowerBound, offsetBy: 1) // "("
        let closingParenIndex = name.index(before: name.endIndex)            // ")"
        guard closingParenIndex > openParenIndex else { return (name, nil) }
        let contentStart = name.index(after: openParenIndex)
        let contentEnd   = closingParenIndex
        let inside = String(name[contentStart..<contentEnd]) // "dosis X/Y"
        if inside.lowercased().hasPrefix("dosis ") {
            let base = String(name[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dose = inside.replacingOccurrences(of: "dosis", with: "Dosis", options: [.anchored, .caseInsensitive])
            return (base, dose)
        } else {
            return (name, nil)
        }
    }
    
    private var icon: String {
        switch event {
        case is Medication:   "pills.fill"
        case is Vaccine:      "syringe"
        case is Deworming:    "ladybug.fill"
        case is Grooming:     "scissors"
        case is WeightEntry:  "scalemass"
        default:              "bell"
        }
    }
    
    var body: some View {
        let parsed = splitDose(from: event.displayName)
        
        HStack(spacing: 12) {
            // ---------- Miniatura ----------
            if let data = event.pet?.photoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "pawprint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    )
            }
            
            // ---------- Texto ----------
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.base)
                    .fontWeight(.semibold)
                
                if let doseLabel = parsed.dose {
                    Text(doseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("🐾 \(event.pet?.name ?? "Sin mascota")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(event.date, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .foregroundStyle(event.isCompleted ? .green : .accentColor)
        }
    }
}

// MARK: - Selector simple de mascota para Quick Add
private struct PetChooserSheet: View {
    let pets: [Pet]
    var onSelect: (Pet) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(pets) { pet in
                Button {
                    onSelect(pet)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        // Foto de la mascota (o placeholder)
                        Group {
                            if let data = pet.photoData,
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "pawprint")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    )
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        
                        Text(pet.name)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationTitle("Selecciona mascota")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", action: dismiss.callAsFunction)
                }
            }
        }
    }
}

// MARK: - Helper para icono de filtro
private extension EventTypeFilter {
    var icon: String {
        switch self {
        case .all:         "circle.dashed"
        case .medication:  "pills"
        case .vaccine:     "syringe"
        case .deworming:   "bandage"
        case .grooming:    "scissors"
        case .weight:      "scalemass"
        }
    }
}

enum PastSectionKind: Int, CaseIterable, Hashable {
    case yesterday = 0, lastWeek, lastMonth, earlier
    
    var label: String {
        switch self {
        case .yesterday:  return "Ayer"
        case .lastWeek:   return "Última semana"
        case .lastMonth:  return "Último mes"
        case .earlier:    return "Más antiguos"
        }
    }
}

extension Calendar {
    /// Clasifica una fecha pasada en Ayer, Última semana, Último mes, Más antiguos.
    func pastSectionKind(for date: Date) -> PastSectionKind {
        if isDateInYesterday(date) { return .yesterday }
        
        let now = Date()
        
        // Hace 7 días
        if let weekAgo = self.date(byAdding: .day, value: -7, to: now),
           date >= weekAgo {
            return .lastWeek
        }
        
        // Hace 1 mes
        if let monthAgo = self.date(byAdding: .month, value: -1, to: now),
           date >= monthAgo {
            return .lastMonth
        }
        
        return .earlier
    }
}


//
//#Preview {
//    EventsListsView()
//}


// MARK: - Preview

#Preview("EventsListView – Vacío") {
    // Contenedor en memoria sin datos
    let container = PreviewData.makeContainer()
    return EventsListViewPreviewHost()
        .modelContainer(container)
}

#Preview("EventsListView – Demo variado") {
    // 1) Contenedor en memoria con el esquema necesario
    let container = PreviewData.makeContainer()
    // 2) Insertamos datos de ejemplo variados
    PreviewData.seed(in: container)
    // 3) Host que toma el modelContext del entorno y lo pasa al init
    return EventsListViewPreviewHost()
        .modelContainer(container)
}

// Host para pasar el mismo ModelContext de entorno al init(context:)
private struct EventsListViewPreviewHost: View {
    @Environment(\.modelContext) private var context
    var body: some View {
        EventsListView(context: context)
    }
}

// Datos de ejemplo para el preview
private enum PreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Pet.self,
            Medication.self,
            Vaccine.self,
            Deworming.self,
            WeightEntry.self,
            Grooming.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
    
    static func seed(in container: ModelContainer) {
        let ctx = ModelContext(container)
        
        // Mascotas
        let loki = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        let mishi = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(loki)
        ctx.insert(mishi)
        
        let cal = Calendar.current
        let now = Date()
        
        // Helpers de fechas futuras
        let in1h = now.addingTimeInterval(3600)
        let in9h = now.addingTimeInterval(9 * 3600)
        let in17h = now.addingTimeInterval(17 * 3600)
        let in25h = now.addingTimeInterval(25 * 3600)
        let in33h = now.addingTimeInterval(33 * 3600)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let nextWeek = cal.date(byAdding: .day, value: 7, to: now)!
        let threeWeeks = cal.date(byAdding: .day, value: 21, to: now)!
        let sixWeeks = cal.date(byAdding: .day, value: 42, to: now)!
        let nextWeekPlus2 = cal.date(byAdding: .day, value: 9, to: now)! // 7 + 2
        let twoMonths = cal.date(byAdding: .month, value: 2, to: now)!
        
        // MEDICAMENTOS
        // 1) Unidosis (solo esta cita)
        let medSingle = Medication(date: tomorrow.addingTimeInterval(2 * 3600),
                                   pet: loki,
                                   name: "Omeprazol",
                                   dosage: "10 mg",
                                   frequency: "cada día")
        
        // 2) Multidosis (serie manual con sufijo " (dosis X/Y)")
        let med1 = Medication(date: in1h, pet: loki,
                              name: "Amoxicilina (dosis 1/5)",
                              dosage: "250 mg",
                              frequency: "cada 8 h")
        let med2 = Medication(date: in9h, pet: loki,
                              name: "Amoxicilina (dosis 2/5)",
                              dosage: "250 mg",
                              frequency: "cada 8 h")
        let med3 = Medication(date: in17h, pet: loki,
                              name: "Amoxicilina (dosis 3/5)",
                              dosage: "250 mg",
                              frequency: "cada 8 h")
        let med4 = Medication(date: in25h, pet: loki,
                              name: "Amoxicilina (dosis 4/5)",
                              dosage: "250 mg",
                              frequency: "cada 8 h")
        let med5 = Medication(date: in33h, pet: loki,
                              name: "Amoxicilina (dosis 5/5)",
                              dosage: "250 mg",
                              frequency: "cada 8 h")
        
        // VACUNAS
        // 1) Unidosis
        let vacSingle = Vaccine(date: nextWeek, pet: mishi,
                                vaccineName: "Rabia",
                                manufacturer: "VetLabs")
        // 2) Serie de 3 dosis (1/3, 2/3, 3/3)
        let vacA = Vaccine(date: tomorrow, pet: mishi,
                           vaccineName: "Moquillo (dosis 1/3)",
                           manufacturer: "PetCare")
        let vacB = Vaccine(date: threeWeeks, pet: mishi,
                           vaccineName: "Moquillo (dosis 2/3)",
                           manufacturer: "PetCare")
        let vacC = Vaccine(date: sixWeeks, pet: mishi,
                           vaccineName: "Moquillo (dosis 3/3)",
                           manufacturer: "PetCare")
        
        // DESPARASITACIÓN – próxima y otra aún más adelante
        let dewFuture1 = Deworming(date: nextWeekPlus2, pet: loki, notes: "Tableta mensual")
        let dewFuture2 = Deworming(date: twoMonths, pet: loki, notes: "Tableta mensual")
        
        // GROOMING – cita próxima
        let groom = Grooming(date: nextWeekPlus2, pet: mishi,
                             location: "Pet Spa", notes: "Baño y corte")
        
        // Insertar todo
        ctx.insert(medSingle)
        ctx.insert(med1); ctx.insert(med2); ctx.insert(med3); ctx.insert(med4); ctx.insert(med5)
        ctx.insert(vacSingle)
        ctx.insert(vacA); ctx.insert(vacB); ctx.insert(vacC)
        ctx.insert(dewFuture1); ctx.insert(dewFuture2)
        ctx.insert(groom)
        
        try? ctx.save()
    }
}


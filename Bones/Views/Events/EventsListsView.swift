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
    @State private var vm: EventsListViewModel
    
    // 3. Estados para Quick Add desde la vista global
    @State private var petForQuickAdd: Pet?
    @State private var showingPetChooser = false
    @State private var showNoPetsAlert = false
    @State private var showingAddPet = false

    @AppStorage(AppStorageKey.eventsDeepLinkPetID)   private var eventsDeepLinkPetID: String = ""
    @AppStorage(AppStorageKey.eventsDeepLinkPetName) private var eventsDeepLinkPetName: String = ""
    @AppStorage(AppStorageKey.eventsDeepLinkAction)  private var eventsDeepLinkAction: String = ""

    // 4. Estados para borrado con confirmación (a nivel padre)
    @State private var pendingDeleteEvent: (any BasicEvent)?
    @State private var pendingFutureCount: Int = 0
    @State private var showingDeleteDialog = false
    
    // 5. Init para inyectar context → VM
    init(context: ModelContext) {
        self.context = context
        _vm = State(wrappedValue: EventsListViewModel(context: context))
    }
    
    // 6. UI
    var body: some View {
        NavigationStack {
            List {
                // Añadimos un id explícito para evitar inferencias costosas
                ForEach(vm.sections, id: \.title) { section in
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
            .overlay {
                if vm.sections.isEmpty {
                    if vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView("Sin eventos próximos",
                                               systemImage: "calendar")
                    } else {
                        ContentUnavailableView.search
                    }
                }
            }
            .navigationTitle("Eventos")
            .toolbar {
                // Botón “+” para agregar evento
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuevo evento", systemImage: "plus", action: startQuickAdd)
                }
                
                // Botón de filtros extraído a un sub‑view para simplificar el árbol
                ToolbarItem(placement: .topBarTrailing) {
                    FiltersMenu(vm: vm)
                }
            }
            .refreshable { vm.fetchAllEvents() }  // pull-to-refresh
            .searchable(text: $vm.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar eventos")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            vm.fetchAllEvents()
        }
        .onAppear {
            applyDeepLinkPetFilterIfNeeded()
            applyDeepLinkActionIfNeeded()
        }
        .onChange(of: eventsDeepLinkPetID) {
            applyDeepLinkPetFilterIfNeeded()
        }
        .onChange(of: eventsDeepLinkAction) {
            applyDeepLinkActionIfNeeded()
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
    
    private func applyDeepLinkPetFilterIfNeeded() {
        guard !eventsDeepLinkPetID.isEmpty else { return }
        let shouldClear = eventsDeepLinkAction != "add"
        if shouldClear {
            defer {
                eventsDeepLinkPetID = ""
                eventsDeepLinkPetName = ""
            }
        }
        guard let uuid = UUID(uuidString: eventsDeepLinkPetID) else { return }
        if let pet = vm.allPets.first(where: { $0.id == uuid }) {
            vm.petFilter = PetFilter(id: pet.id, name: pet.name)
        } else if !eventsDeepLinkPetName.isEmpty {
            vm.petFilter = PetFilter(id: uuid, name: eventsDeepLinkPetName)
        }
    }

    private func applyDeepLinkActionIfNeeded() {
        guard eventsDeepLinkAction == "add" else { return }
        defer {
            eventsDeepLinkAction = ""
            eventsDeepLinkPetID = ""
            eventsDeepLinkPetName = ""
        }
        if let uuid = UUID(uuidString: eventsDeepLinkPetID),
           let pet = vm.allPets.first(where: { $0.id == uuid }) {
            petForQuickAdd = pet
        } else {
            startQuickAdd()
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
        case let vac as Vaccine:
            count = max(0, DoseSeries.futureVaccines(from: vac, in: context).count - 1)
        case let dew as Deworming:
            count = max(0, DoseSeries.futureDewormings(from: dew, in: context).count - 1)
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
        case let vac as Vaccine:
            for v in DoseSeries.futureVaccines(from: vac, in: context) {
                NotificationManager.shared.cancelNotification(id: v.id)
                context.delete(v)
            }
            try? context.save()
        case let dew as Deworming:
            for d in DoseSeries.futureDewormings(from: dew, in: context) {
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
    

    
}

// MARK: - Filtros (sub‑view para simplificar el árbol del toolbar)
private struct FiltersMenu: View {
    @Bindable var vm: EventsListViewModel
    
    var body: some View {
        Menu {
            // Mostrar vencidos y completados (según el nuevo VM)
            Toggle("Mostrar vencidos", isOn: $vm.showOverdue)
            Toggle("Incluir completados", isOn: $vm.includeCompletedPast)
            
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
                .pickerStyle(.inline)
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
            Label("Filtros", systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.iconOnly)
        }
    }
}

// MARK: - Fila reutilizable (solo UI; los swipes están en el padre)
private struct EventRow: View {
    let event: any BasicEvent
    
    
    private var icon: String {
        switch event {
        case is Vaccine:      "syringe"
        case is Deworming:    "ladybug.fill"
        case is WeightEntry:  "scalemass"
        default:              "bell"
        }
    }
    
    private var tint: Color {
        switch event {
        case is Vaccine:     return .green
        case is Deworming:   return .orange
        case is WeightEntry: return .gray
        default:             return .secondary
        }
    }
    
    var body: some View {
        let parsed = DoseSeries.splitDose(from: event.displayName)
        let now = Date.now
        let cal = Calendar.current
        let isOverdue = !event.isCompleted && event.date < now
        let isTodayOrTomorrow = cal.isDateInToday(event.date) || cal.isDateInTomorrow(event.date)
        
        HStack(spacing: 12) {
            // ---------- Miniatura ----------
            if let data = event.pet?.photoData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
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
                HStack(spacing: 6) {
                    Text(parsed.base)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    if isOverdue {
                        TagChip(text: "Vencida", tint: .red)
                    }
                }
                
                HStack(spacing: 6) {
                    if !event.displayType.isEmpty {
                        TagChip(text: shortTypeLabel, tint: tint)
                    }
                    if let doseLabel = parsed.dose {
                        TagChip(text: doseLabel, tint: .secondary)
                    }
                    if !isTodayOrTomorrow {
                        TagChip(text: event.date.formatted(.dateTime.day().month().year()), tint: .secondary)
                    }
                }
            }
            
            Spacer()
            if isTodayOrTomorrow {
                Text(event.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 56, alignment: .trailing)
            }
        }
    }
    
    private var shortTypeLabel: String {
        if event.displayType == "Desparasitación" { return "Despar." }
        return event.displayType
    }
}

private struct TagChip: View {
    let text: String
    let tint: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .foregroundStyle(tint)
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
        case .vaccine:     "syringe"
        case .weight:      "scalemass"
        }
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

// Nuevo preview con eventos vencidos realistas y futuros
#Preview("EventsListView – Vencidos variados") {
    let container = PreviewData.makeContainer()
    PreviewData.seedOverdueScenario(in: container)
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
            Vaccine.self,
            Deworming.self,
            WeightEntry.self
        ] as [any PersistentModel.Type])
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
        let now = Date.now
        
        // Helpers de fechas futuras
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let nextWeek = cal.date(byAdding: .day, value: 7, to: now)!
        let threeWeeks = cal.date(byAdding: .day, value: 21, to: now)!
        let sixWeeks = cal.date(byAdding: .day, value: 42, to: now)!
        let nextWeekPlus2 = cal.date(byAdding: .day, value: 9, to: now)! // 7 + 2
        let twoMonths = cal.date(byAdding: .month, value: 2, to: now)!
        
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
        
        // Insertar todo
        ctx.insert(vacSingle)
        ctx.insert(vacA); ctx.insert(vacB); ctx.insert(vacC)
        ctx.insert(dewFuture1); ctx.insert(dewFuture2)
        
        try? ctx.save()
    }
    
    // Nuevo dataset: mezcla de vencidos (hoy, ayer, semana, mes, más antiguos) y futuros
    static func seedOverdueScenario(in container: ModelContainer) {
        let ctx = ModelContext(container)
        let cal = Calendar.current
        let now = Date.now
        
        let loki = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        let mishi = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(loki)
        ctx.insert(mishi)
        
        func at(hour: Int, minute: Int, on base: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: base)
            comps.hour = hour
            comps.minute = minute
            return cal.date(from: comps) ?? base
        }
        
        // Ayer
        let yesterdayBase = cal.date(byAdding: .day, value: -1, to: now)!
        let yesterday10am = at(hour: 10, minute: 0, on: yesterdayBase)
        let vacYesterday = Vaccine(date: yesterday10am, pet: mishi, vaccineName: "Rabia", manufacturer: "VetLabs")
        
        // Última semana (no ayer)
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now)!
        let dewLastWeek = Deworming(date: at(hour: 9, minute: 30, on: threeDaysAgo), pet: loki, notes: "Tableta mensual")
        
        // Último mes (entre 7 días y 1 mes)
        let twentyDaysAgo = cal.date(byAdding: .day, value: -20, to: now)!
        let weightLastMonth = WeightEntry(date: at(hour: 16, minute: 0, on: twentyDaysAgo), pet: mishi, weightKg: 4.2)
        
        // Más antiguos (más de 1 mes)
        let fiftyDaysAgo = cal.date(byAdding: .day, value: -50, to: now)!
        let weightOlder = WeightEntry(date: at(hour: 8, minute: 15, on: fiftyDaysAgo), pet: loki, weightKg: 22.4, notes: "Control general")
        
        // Futuros: mañana, próxima semana, próximo mes
        let nextWeek = cal.date(byAdding: .day, value: 7, to: now)!
        let nextMonth = cal.date(byAdding: .month, value: 1, to: now)!

        let vacNextWeek = Vaccine(date: at(hour: 9, minute: 0, on: nextWeek), pet: mishi, vaccineName: "Moquillo (dosis 1/3)", manufacturer: "PetCare")
        let dewNextMonth = Deworming(date: at(hour: 11, minute: 30, on: nextMonth), pet: loki, notes: "Tableta mensual")
        
        // Marcar algunos pasados como completados para cubrir ambos casos en “Pasados”
        vacYesterday.isCompleted = true
        weightLastMonth.isCompleted = true
        
        // Insertar
        ctx.insert(vacYesterday)
        ctx.insert(dewLastWeek)
        ctx.insert(weightLastMonth)
        ctx.insert(weightOlder)
        ctx.insert(vacNextWeek)
        ctx.insert(dewNextMonth)
        
        try? ctx.save()
    }
}

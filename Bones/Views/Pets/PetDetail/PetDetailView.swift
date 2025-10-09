//
//  PetDetailView.swift
//  Bones
//
//  Created by Felipe Duarte on 11/07/25.
//

import SwiftUI
import SwiftData
import PhotosUI


// MARK: - Detalle de la mascota
struct PetDetailView: View {
    // Entrada
    let pet: Pet
    
    // Contexto de SwiftData disponible para toda la vista
    @Environment(\.modelContext) private var context
    
    // ViewModel – se crea con el id de la mascota
    @StateObject private var viewModel: PetDetailViewModel
    
    // Picker interno
    @State private var selectedTab: DetailTab = .upcoming

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingRemoveAlert = false
    @State private var isPresentingEdit = false
    
    // Animación de la barra de tabs
    @Namespace private var tabNamespace
    
    // Estado del subsegmento de Salud (elevado desde PetHealthTab)
    @State private var healthSegment: PetHealthTab.HealthSegment = .vaccines

    // Inicializador para inyectar el ViewModel
    init(pet: Pet) {
        self.pet = pet
        // Break up the expression to help the type-checker
        let id: UUID = pet.id
        let vm = PetDetailViewModel(petID: id)
        _viewModel = StateObject(wrappedValue: vm)   // aún sin contexto
    }
    
    var body: some View {
        VStack(spacing: 0) {

            // ---------- Cabecera ----------
            HStack(alignment: .top, spacing: 16) {
                // Foto (círculo o rectángulo redondeado)
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = pet.photoData,
                           let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                                .padding(20)
                        }
                    }
                    .frame(width: 120, height: 120)        // tamaño fijo
                    .clipShape(Circle())                   // cambia a RoundedRectangle si prefieres
                    .contentShape(Rectangle())             // para gestos
                    
                    // Botón editar
                    PhotosPicker(selection: $selectedItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 26))
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .onLongPressGesture { showingRemoveAlert = true }
                }
                
                // Datos a la derecha
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title2).bold()
                    HStack {
                        Text(pet.sex.rawValue.capitalized)
                        Text("|")
                        if let age = ageString(for: pet.birthDate) {
                            Text(age)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Text("\(pet.species.rawValue.capitalized) · \(pet.breed ?? "Sin raza")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let color = pet.color, !color.isEmpty {
                        Text("Color: \(color)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)

            
            // ---------- Picker de tabs (chips ancho completo + animación) ----------
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline)
                            .minimumScaleFactor(0.85)
                            .lineLimit(1)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .background(
                                ZStack {
                                    // Fondo base
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                    // Fondo seleccionado animado
                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color.accentColor)
                                            .matchedGeometryEffect(id: "tabSelection", in: tabNamespace)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            
            // ---------- Contenido ----------
            Group {
                switch selectedTab {
                case .upcoming:
                    PetUpcomingEventsTab(viewModel: viewModel)
                case .health:
                    PetHealthTab(viewModel: viewModel, segment: $healthSegment)   // Vacunas + Desparasitación + Medicamentos
                case .grooming:
                    PetGroomingTab(viewModel: viewModel)
                case .weight:
                    PetWeightTab(pet: pet, viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    pet.photoData = data
                    try? context.save()
                    selectedItem = nil           // ← resetea para permitir nueva selección
                }
            }
        }

        .alert("¿Eliminar foto?", isPresented: $showingRemoveAlert) {
            Button("Eliminar", role: .destructive) {
                pet.photoData = nil
                try? context.save()
            }
            Button("Cancelar", role: .cancel) { }
        }

        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Editar", systemImage: "pencil") { isPresentingEdit = true }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    // Decidir initialKind y isDewormingInitial según la ubicación actual
                    let (initialKind, isDewormingInitial): (EventKind, Bool) = {
                        if selectedTab == .health {
                            switch healthSegment {
                            case .vaccines:
                                return (.vaccine, false)
                            case .deworm:
                                return (.medication, true)
                            case .medications:
                                return (.medication, false)
                            }
                        } else {
                            // Fallback a comportamiento anterior por pestaña general
                            switch selectedTab {
                            case .grooming: return (.grooming, false)
                            case .weight:   return (.weight, false)
                            case .health, .upcoming:
                                return (.medication, false)
                            }
                        }
                    }()
                    // DEBUG: log de intención calculada
                    print("[QuickAdd] Intent from tab=\(selectedTab) segment=\(healthSegment) → kind=\(initialKind) deworm=\(isDewormingInitial)")
                    // Abrimos la hoja con un item identificable (evita condiciones de carrera)
                    quickAddConfig = QuickAddConfig(kind: initialKind, isDeworming: isDewormingInitial)
                } label: {
                    Label("Nuevo evento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $quickAddConfig, onDismiss: {
            viewModel.fetchEvents()          // refresca la lista al volver
        }) { config in
            EventQuickAddSheet(pet: pet,
                               initialKind: config.kind,
                               isDewormingInitial: config.isDeworming)
            .onAppear {
                print("[QuickAdd] Sheet onAppear with intent kind=\(config.kind) deworm=\(config.isDeworming)")
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditPetSheet(pet: pet)
        }

        // Inyectamos el context real en el ViewModel al aparecer
        .onAppear { viewModel.inject(context: context) }
        // DEBUG: trazas de navegación entre tabs/subtabs
        .onChange(of: selectedTab) { old, new in
            print("[QuickAdd] selectedTab \(old) → \(new)")
        }
        .onChange(of: healthSegment) { old, new in
            print("[QuickAdd] healthSegment \(old) → \(new)")
        }
    }
    
    // QuickAdd: modelo identificable para .sheet(item:)
    struct QuickAddConfig: Identifiable, Equatable {
        let id = UUID()
        let kind: EventKind
        let isDeworming: Bool
    }
    @State private var quickAddConfig: QuickAddConfig?
}

// MARK: - Enum de tabs
enum DetailTab: CaseIterable {
    case upcoming, health, grooming, weight
    
    var title: String {
        switch self {
        case .upcoming:     return "Próximos"
        case .health:       return "Salud"
        case .grooming:     return "Grooming"
        case .weight:       return "Peso"
        }
    }
}

extension DetailTab {
    var defaultEventKind: EventKind {
        switch self {
        case .health:       return .vaccine       // Quick Add desde Salud: por defecto vacuna
        case .grooming:     return .grooming
        case .weight:       return .weight
        default:            return .medication   // Upcoming u otra
        }
    }
}

private func ageString(for birth: Date?) -> String? {
    guard let birth else { return nil }
    let comp = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
    let y = comp.year ?? 0, m = comp.month ?? 0
    switch (y, m) {
    case (0, 0):  return "Recién nacido"
    case (0, _):  return "\(m) mes\(m > 1 ? "es" : "")"
    default:      return "\(y) año\(y > 1 ? "s" : "") \(m) m"
    }
}

// MARK: - Preview

#Preview {
    // 1. Creamos una instancia de Pet con datos de ejemplo
    let samplePet = Pet(
        name: "Loki",
        species: .perro,
        breed: "Husky",
        birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
        sex: .male,
        color: "White"
    )
    PetDetailView(pet: samplePet)
}

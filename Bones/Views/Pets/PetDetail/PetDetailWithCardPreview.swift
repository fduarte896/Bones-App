import SwiftUI
import SwiftData
import PhotosUI

struct PetDetailWithCardPreview: View {
    let pet: Pet
    @Environment(\.modelContext) private var context

    @State private var selectedTab: DetailTabWithCard = .upcoming

    enum DetailTabWithCard: CaseIterable {
        case upcoming, health, grooming, weight, vaccineCard

        var title: String {
            switch self {
            case .upcoming:   return "Próximos"
            case .health:     return "Salud"
            case .grooming:   return "Grooming"
            case .weight:     return "Peso"
            case .vaccineCard: return "Carnet vacunas"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Cabecera de la mascota
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let data = pet.photoData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "pawprint.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .padding(20)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title2.bold())
                    HStack {
                        Text(pet.sex.rawValue.capitalized)
                        Text("|")
                        if let age = ageString(for: pet.birthDate) { Text(age) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Text("\(pet.species.rawValue.capitalized) · \(pet.breed ?? "Sin raza")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

            // Chips/tabs
            HStack(spacing: 8) {
                ForEach(DetailTabWithCard.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Color.accentColor : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Contenido de cada tab
            Group {
                switch selectedTab {
                case .upcoming:
                    ContentUnavailableView("Demo tab", systemImage: "calendar")
                case .health:
                    ContentUnavailableView("Demo Salud", systemImage: "cross.case")
                case .grooming:
                    ContentUnavailableView("Demo Grooming", systemImage: "scissors")
                case .weight:
                    ContentUnavailableView("Demo Peso", systemImage: "scalemass")
                case .vaccineCard:
                    DigitalVaccineCardView(pet: pet)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Helper de edad (misma lógica que tu PetDetailView)
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

// Preview con datos sembrados para popular la tabla del carnet
#Preview("Detalle con carnet poblado") {
    // 1) Contenedor en memoria con Pet y Vaccine
    let schema = Schema([Pet.self, Vaccine.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    let context = ModelContext(container)

    // 2) Crear mascota de ejemplo
    let pet = Pet(
        name: "Loki",
        species: .perro,
        breed: "Husky",
        birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
        sex: .male,
        color: "Blanco"
    )
    // Foto opcional de sistema como demo
    if let img = UIImage(systemName: "pawprint.fill")?.withRenderingMode(.alwaysOriginal),
       let data = img.pngData() {
        pet.photoData = data
    }
    context.insert(pet)

    // 3) Sembrar vacunas (pasadas y futuras), con y sin etiqueta
    let now = Date()
    let cal = Calendar.current

    let rabia1 = Vaccine(
        date: cal.date(byAdding: .day, value: -120, to: now) ?? now.addingTimeInterval(-120*24*3600),
        pet: pet,
        vaccineName: "Rabia"
    )
    rabia1.manufacturer = "AcmeVet"
    // Simular una etiqueta como imagen generada desde SF Symbol
    if let sticker = UIImage(systemName: "bandage.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal),
       let stickerData = sticker.pngData() {
        rabia1.prescriptionImageData = stickerData
    }

    let moquillo = Vaccine(
        date: cal.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30*24*3600),
        pet: pet,
        vaccineName: "Moquillo"
    )
    moquillo.manufacturer = "PetLabs"

    let parvo = Vaccine(
        date: cal.date(byAdding: .day, value: 10, to: now) ?? now.addingTimeInterval(10*24*3600),
        pet: pet,
        vaccineName: "Parvovirus"
    )
    parvo.manufacturer = "VetHealth"

    let rabiaRefuerzo = Vaccine(
        date: cal.date(byAdding: .month, value: 11, to: now) ?? now.addingTimeInterval(11*30*24*3600),
        pet: pet,
        vaccineName: "Rabia (refuerzo anual)"
    )
    rabiaRefuerzo.manufacturer = "AcmeVet"

    context.insert(rabia1)
    context.insert(moquillo)
    context.insert(parvo)
    context.insert(rabiaRefuerzo)
    try? context.save()

    return NavigationStack {
        PetDetailWithCardPreview(pet: pet)
    }
    .modelContainer(container)
    .environment(\.locale, Locale(identifier: "es"))
}

struct DigitalVaccineCardView: View {
    let pet: Pet
    @Environment(\.modelContext) private var context

    @Query(sort: \Vaccine.date) private var allVaccines: [Vaccine]

    @State private var showingStickerPickerFor: Vaccine.ID?
    @State private var tempStickerData: Data?

    // Ejemplo de esquema simple para perros en Colombia
    private let requiredVaccines = [
        "Rabia", "Moquillo", "Parvovirus", "Hepatitis", "Leptospira"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Carnet de Vacunación")
                .font(.title2.bold())
                .padding(.bottom, 8)

            HStack {
                Text("Fecha").font(.footnote.bold()).frame(width: 78, alignment: .center)
                // Vacuna: columna flexible
                Text("Vacuna")
                    .font(.footnote.bold())
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                Text("Etiqueta").font(.footnote.bold()).frame(width: 110, alignment: .center)
                Text("Próxima dosis").font(.footnote.bold()).frame(width: 110, alignment: .center)
            }
            .padding(.bottom, 2)
            .foregroundColor(.secondary)

            ForEach(vaccinesForPet) { v in
                HStack(alignment: .center, spacing: 0) {
                    // Fecha aplicación
                    Text(v.date, format: .dateTime.day().month().year())
                        .frame(width: 78, alignment: .center)

                    // Columna: Nombre de la vacuna (+ fabricante opcional) – flexible
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.vaccineName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let mfg = v.manufacturer, !mfg.isEmpty {
                            Text(mfg)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)

                    // Sticker/etiqueta
                    Button {
                        showingStickerPickerFor = v.id
                    } label: {
                        if let sticker = v.prescriptionImageData, let img = UIImage(data: sticker) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 95, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary, lineWidth: 1))
                                .shadow(radius: 1, x: 0, y: 1)
                                .padding(.horizontal, 6)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.yellow.opacity(0.15))
                                Text("Sin etiqueta")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 95, height: 38)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary, lineWidth: 1))
                            .shadow(radius: 1)
                            .padding(.horizontal, 6)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: Binding(
                        get: { showingStickerPickerFor == v.id },
                        set: { show in
                            if !show { showingStickerPickerFor = nil }
                        }
                    )) {
                        StickerPicker(
                            current: v.prescriptionImageData,
                            onSave: { data in
                                v.prescriptionImageData = data
                                try? context.save()
                                showingStickerPickerFor = nil
                            },
                            onDelete: {
                                v.prescriptionImageData = nil
                                try? context.save()
                                showingStickerPickerFor = nil
                            }
                        )
                    }

                    // Próxima dosis (ejemplo cálculo para rabia)
                    Text(v.nextDoseDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "")
                        .font(.caption2)
                        .frame(width: 110, alignment: .center)
                }
                .frame(height: 44)
                .background((v.prescriptionImageData != nil ? Color.clear : Color(.systemGray6)).opacity(0.45))
                .cornerRadius(8)
            }
            .padding(.bottom, 1)

            Button {
                // Aquí: abrir flujo para añadir nueva vacuna (conecta a tu quick add)
            } label: {
                Label("Añadir vacuna", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .padding()
    }

    private var vaccinesForPet: [Vaccine] {
        allVaccines.filter { $0.pet?.id == pet.id }
            .sorted { $0.date < $1.date }
    }
}

// Calcula próxima dosis de ejemplo
extension Vaccine {
    var nextDoseDate: Date? {
        // Puedes hacer lógica específica por nombre
        if vaccineName.localizedCaseInsensitiveContains("rabia") {
            return Calendar.current.date(byAdding: .month, value: 12, to: date)
        }
        // Puedes añadir más reglas aquí
        return nil
    }
}

// Picker para adjuntar/eliminar sticker/etiqueta
struct StickerPicker: View {
    var current: Data?
    var onSave: (Data) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let img = tempImage ?? (current.flatMap { UIImage(data: $0) }) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                    Button("Eliminar etiqueta", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                } else {
                    Text("Adjunta una foto de la etiqueta/sticker de la vacuna")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Seleccionar foto", systemImage: "photo.on.rectangle")
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let img = tempImage, let data = img.jpegData(compressionQuality: 0.85) {
                        Button("Guardar") {
                            onSave(data)
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            tempImage = img
                        }
                    }
                }
            }
        }
    }
}

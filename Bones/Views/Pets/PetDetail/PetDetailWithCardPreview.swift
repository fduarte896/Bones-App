import SwiftUI
import SwiftData

struct PetDetailWithCardPreview: View {
    let pet: Pet
    @Environment(\.modelContext) private var context

    @State private var selectedTab: DetailTabWithCard = .upcoming

    // Puedes duplicar tus tabs actuales y agregar uno más
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
            // Copia de tu cabecera de mascota (puedes personalizar)
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
                    VaccinationCardView(pet: pet)
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

// Pega aquí la VaccinationCardView y sus helpers (de la respuesta anterior)


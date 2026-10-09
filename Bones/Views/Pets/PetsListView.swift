import SwiftUI
import SwiftData
import UIKit

struct PetsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.name) private var pets: [Pet]
    @AppStorage(AppStorageKey.didChooseDemoPet)     private var didChooseDemoPet: Bool = false
    @AppStorage(AppStorageKey.demoGuideStep)        private var demoGuideStep: Int = 0
    @AppStorage(AppStorageKey.didCompleteDemoGuide) private var didCompleteDemoGuide: Bool = false

    @State private var isPresentingAdd = false
    @State private var petToEdit: Pet?
    @State private var navigateToPetDetail: Pet?

    var body: some View {
        NavigationStack {
            Group {
                if pets.isEmpty {
                    EmptyStateView(onAddPet: { isPresentingAdd = true })
                } else if pets.count == 1, let pet = pets.first {
                    VetProDashboard(
                        pet: pet,
                        demoGuideStep: $demoGuideStep,
                        didCompleteDemoGuide: $didCompleteDemoGuide,
                        onEdit: { petToEdit = pet }
                    )
                    .navigationTitle("Resumen")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            navAddButton
                                .demoGuideAnchor(.addPetButton)
                        }
                    }
                } else if pets.count <= 3 {
                    VetProCarousel(pets: pets, onEdit: { petToEdit = $0 })
                        .navigationTitle("Mascotas")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                navAddButton
                            }
                        }
                } else {
                    VetProGrid(pets: pets, onEdit: { petToEdit = $0 })
                        .navigationTitle("Mascotas")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                navAddButton
                            }
                        }
                }
            }
            .navigationDestination(item: $navigateToPetDetail) { pet in
                PetDetailView(pet: pet)
            }
        }
        .sheet(isPresented: $isPresentingAdd) { AddPetSheet() }
        .sheet(item: $petToEdit) { pet in EditPetSheet(pet: pet) }
        .overlayPreferenceValue(DemoGuideAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if shouldShowDemoGuide,
                   let step = DemoGuideStep(rawValue: demoGuideStep) {
                    switch step {
                    case .summary:
                        if let anchor = anchors[.dashboardHeader] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Resumen de Marcos",
                                message: "Aquí ves lo esencial de su salud y próximos cuidados.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: { demoGuideStep = DemoGuideStep.addPet.rawValue },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    case .addPet:
                        if let anchor = anchors[.addPetButton] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Añade otra mascota",
                                message: "Usa este + para crear un nuevo perfil.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: {
                                    demoGuideStep = DemoGuideStep.upcoming.rawValue
                                    openDetailIfPossible()
                                },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    case .detail:
                        if let anchor = anchors[.detailButton] {
                            DemoGuideOverlay(
                                targetRect: proxy[anchor],
                                title: "Ver detalle",
                                message: "Entra al perfil completo para ver pestañas y eventos.",
                                primaryActionTitle: "Siguiente",
                                onPrimaryAction: {
                                    demoGuideStep = DemoGuideStep.upcoming.rawValue
                                    openDetailIfPossible()
                                },
                                onSkip: skipDemoGuide,
                                presentationStyle: .centered
                            )
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var navAddButton: some View {
        Button {
            if demoGuideStep == DemoGuideStep.addPet.rawValue {
                demoGuideStep = DemoGuideStep.detail.rawValue
            }
            isPresentingAdd = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.bonesInk)
                    .frame(width: 30, height: 30)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var shouldShowDemoGuide: Bool {
        didChooseDemoPet && !didCompleteDemoGuide && demoGuideStep <= DemoGuideStep.detail.rawValue
    }

    private func skipDemoGuide() { didCompleteDemoGuide = true }

    private func openDetailIfPossible() {
        if let pet = pets.first { navigateToPetDetail = pet }
    }
}

// MARK: - Private helpers

private struct DetailNavTarget: Identifiable, Hashable {
    let id = UUID()
    let tab: DetailTab
}

private struct PetQuickAdd: Identifiable {
    let id = UUID()
    let pet: Pet
    let kind: EventKind
}

private struct CarouselNavTarget: Identifiable, Hashable {
    let petID: UUID
    let tab: DetailTab
    var id: String { "\(petID)-\(tab)" }
}

// MARK: - A · Empty State

private struct EmptyStateView: View {
    let onAddPet: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 44)

                // Central card
                VStack(spacing: 24) {
                    // Stacked cards illustration
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.bonesRule)
                            .frame(width: 76, height: 58)
                            .rotationEffect(.degrees(-9))
                            .offset(x: -14, y: 8)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.bonesRuleSoft)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.bonesRule, lineWidth: 1))
                            .frame(width: 76, height: 58)
                            .rotationEffect(.degrees(6))
                            .offset(x: 12, y: 4)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.bonesPanel)
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(Color.bonesRule)
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    .foregroundStyle(Color.bonesRule)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.bonesInkFaint)
                            }
                        }
                        .frame(width: 76, height: 58)
                    }
                    .frame(height: 96)

                    VStack(spacing: 8) {
                        Text("Aún no hay mascotas")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.bonesInk)
                        Text("Añade tu primera mascota para llevar un registro de su salud y cuidados.")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.bonesInkSoft)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }

                    Button(action: onAddPet) {
                        Label("Añadir mascota", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Color.bonesInk))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.bonesPanel)
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.bonesRule, lineWidth: 1))
                )
                .padding(.horizontal, 20)

                // 3-up feature grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUÉ PUEDES REGISTRAR")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.bonesInkFaint)
                        .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        FeatureChip(icon: "syringe.fill",    label: "Vacunas",    color: .bonesVaccine)
                        FeatureChip(icon: "drop.fill",       label: "Desparas.",  color: .bonesDeworming)
                        FeatureChip(icon: "scalemass.fill",  label: "Peso",       color: .bonesWeight)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 44)
            }
        }
        .background(Color.bonesBg.ignoresSafeArea())
    }
}

private struct FeatureChip: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 15))
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.bonesInkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
    }
}

// MARK: - B · Dashboard (1 mascota)

private struct VetProDashboard: View {
    @Environment(\.modelContext) private var context
    let pet: Pet
    @Binding var demoGuideStep: Int
    @Binding var didCompleteDemoGuide: Bool
    let onEdit: () -> Void

    @State private var detailDestination: DetailNavTarget?
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                    .demoGuideAnchor(.dashboardHeader)
                upcomingSection
                statusSection
                hintCard
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.bonesBg.ignoresSafeArea())
        .navigationDestination(item: $detailDestination) { target in
            PetDetailView(pet: pet, initialTab: target.tab)
        }
        .alert("¿Eliminar mascota?", isPresented: $showingDeleteAlert) {
            Button("Eliminar", role: .destructive) { deletePet() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer. Se eliminarán también todos sus eventos.")
        }
    }

    // MARK: Hero card
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [pet.tone.hue.opacity(0.14), pet.tone.hue.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)

                HStack(spacing: 14) {
                    NavigationLink {
                        PetDetailView(pet: pet, initialTab: .upcoming)
                    } label: {
                        Monogram(pet: pet, size: 68, radius: 18)
                    }
                    .buttonStyle(.plain)
                    .demoGuideAnchor(.detailButton)
                    .simultaneousGesture(TapGesture().onEnded {
                        if demoGuideStep == DemoGuideStep.detail.rawValue {
                            demoGuideStep = DemoGuideStep.upcoming.rawValue
                        }
                    })

                    VStack(alignment: .leading, spacing: 5) {
                        Text(pet.name)
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(Color.bonesInk)
                        StatusPill(status: pet.healthStatus, label: pet.healthStatusLabel)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            HStack(spacing: 6) {
                Text(pet.species.rawValue.capitalized)
                if let breed = pet.breed, !breed.isEmpty {
                    Text("·").foregroundStyle(Color.bonesInkFaint)
                    Text(breed)
                }
                if let age = ageString(for: pet.birthDate) {
                    Text("·").foregroundStyle(Color.bonesInkFaint)
                    Text(age)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                Spacer(minLength: 0)
                Button { onEdit() } label: {
                    Text("Editar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.bonesInkSoft)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Capsule().strokeBorder(Color.bonesRule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(Color.bonesInkSoft)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Upcoming section
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Próximos eventos")
            HStack(spacing: 10) {
                Group {
                    if let vac = nextVaccine() {
                        KpiCard(
                            icon: "syringe.fill", iconColor: .bonesVaccine,
                            pillLabel: bonesRelativeLabel(for: vac.date),
                            eyebrow: "Próx. vacuna",
                            dateText: bonesShortDate(vac.date),
                            eventName: DoseSeries.splitDoseBase(from: vac.vaccineName),
                            date: vac.date,
                            status: eventStatus(vac.date)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { detailDestination = DetailNavTarget(tab: .vaccines) }
                    } else {
                        emptyKpiCard(icon: "syringe.fill", iconColor: .bonesVaccine, label: "Próx. vacuna")
                            .onTapGesture { detailDestination = DetailNavTarget(tab: .vaccines) }
                    }
                }
                Group {
                    if let dew = nextDeworming() {
                        KpiCard(
                            icon: "drop.fill", iconColor: .bonesDeworming,
                            pillLabel: bonesRelativeLabel(for: dew.date),
                            eyebrow: "Próx. desparas.",
                            dateText: bonesShortDate(dew.date),
                            eventName: dew.notes ?? "Desparasitación",
                            date: dew.date,
                            status: eventStatus(dew.date)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { detailDestination = DetailNavTarget(tab: .deworming) }
                    } else {
                        emptyKpiCard(icon: "drop.fill", iconColor: .bonesDeworming, label: "Próx. desparas.")
                            .onTapGesture { detailDestination = DetailNavTarget(tab: .deworming) }
                    }
                }
            }
        }
    }

    // MARK: Status section
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Estado")
            VStack(spacing: 0) {
                weightRow
                Divider().background(Color.bonesRule).padding(.horizontal, 14)
                lastVaccineRow
                Divider().background(Color.bonesRule).padding(.horizontal, 14)
                lastDewormingRow
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bonesPanel)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.bonesRule, lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var weightRow: some View {
        let weights = sortedWeights()
        let last = weights.first
        let (deltaStr, trend): (String?, WeightTrend?) = {
            guard weights.count >= 2 else { return (nil, nil) }
            let diff = weights[0].weightKg - weights[1].weightKg
            if abs(diff) < 0.05 { return ("+0.0", .flat) }
            let sign = diff > 0 ? "+" : ""
            return ("\(sign)\(String(format: "%.1f", diff))", diff > 0 ? .up : .down)
        }()

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.bonesBg)
                    .frame(width: 30, height: 30)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bonesWeight)
            }
            Text("PESO")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
            Spacer(minLength: 0)
            if let w = last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", w.weightKg))
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.bonesInk)
                    Text("kg")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bonesInkSoft)
                }
                if let ds = deltaStr, let tr = trend {
                    DeltaBadge(delta: ds, trend: tr)
                }
                Text(bonesRelativeLabel(for: w.date))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.bonesInkFaint)
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.bonesInkFaint)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture { detailDestination = DetailNavTarget(tab: .weight) }
    }

    private var lastVaccineRow: some View {
        Group {
            if let lv = lastVaccine() {
                RegRow(
                    icon: "syringe.fill", iconColor: .bonesVaccine,
                    label: "Última vacuna",
                    value: DoseSeries.splitDoseBase(from: lv.vaccineName),
                    meta: bonesShortDate(lv.date)
                )
                .contentShape(Rectangle())
                .onTapGesture { detailDestination = DetailNavTarget(tab: .vaccines) }
            } else {
                RegRow(
                    icon: "syringe.fill", iconColor: .bonesVaccine,
                    label: "Última vacuna", value: "Sin registrar", meta: nil
                )
            }
        }
    }

    private var lastDewormingRow: some View {
        Group {
            if let ld = lastDeworming() {
                RegRow(
                    icon: "drop.fill", iconColor: .bonesDeworming,
                    label: "Última desparas.",
                    value: ld.notes ?? "Desparasitación",
                    meta: bonesShortDate(ld.date)
                )
                .contentShape(Rectangle())
                .onTapGesture { detailDestination = DetailNavTarget(tab: .deworming) }
            } else {
                RegRow(
                    icon: "drop.fill", iconColor: .bonesDeworming,
                    label: "Última desparas.", value: "Sin registrar", meta: nil
                )
            }
        }
    }

    private var hintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.to.line")
                .font(.system(size: 16))
                .foregroundStyle(Color.bonesInkFaint)
            Text("En la lista de mascotas, desliza una tarjeta a la izquierda para registrar peso o vacuna rápidamente.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.bonesInkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.bonesPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.bonesRule)
                )
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            Text("Eliminar mascota")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bonesOverdue.opacity(0.7))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.bonesInkFaint)
    }

    private func emptyKpiCard(icon: String, iconColor: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
            Text("Sin programar")
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.bonesInkFaint)
        }
        .contentShape(Rectangle())
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
    }

    private func eventStatus(_ date: Date) -> HealthStatus {
        let now = Date()
        if date < now { return .overdue }
        if date.timeIntervalSince(now) < 7 * 24 * 3600 { return .soon }
        return .ok
    }

    // MARK: Fetch helpers
    private func nextVaccine() -> Vaccine? {
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func nextDeworming() -> Deworming? {
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.isCompleted && $0.date <= now }
    }

    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.isCompleted && $0.date <= now }
    }

    private func sortedWeights() -> [WeightEntry] {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.filter { $0.pet?.id == pet.id }
    }

    private func deletePet() {
        let vacs    = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews    = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        for e in vacs    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in weights where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        context.delete(pet)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - C · Carousel (2-3 mascotas)

private struct VetProCarousel: View {
    let pets: [Pet]
    let onEdit: (Pet) -> Void

    @State private var navTarget: CarouselNavTarget?

    var body: some View {
        TabView {
            ForEach(pets) { pet in
                PetCarouselCard(
                    pet: pet,
                    onEdit: { onEdit(pet) },
                    onNavigate: { tab in navTarget = CarouselNavTarget(petID: pet.id, tab: tab) }
                )
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.bonesBg.ignoresSafeArea())
        .navigationDestination(item: $navTarget) { target in
            if let pet = pets.first(where: { $0.id == target.petID }) {
                PetDetailView(pet: pet, initialTab: target.tab)
            }
        }
    }
}

private struct PetCarouselCard: View {
    @Environment(\.modelContext) private var context
    let pet: Pet
    let onEdit: () -> Void
    let onNavigate: (DetailTab) -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                upcomingSection
                statusSection
                deleteButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.bonesBg.ignoresSafeArea())
        .alert("¿Eliminar mascota?", isPresented: $showingDeleteAlert) {
            Button("Eliminar", role: .destructive) { deletePet() }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción no se puede deshacer. Se eliminarán también todos sus eventos.")
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [pet.tone.hue.opacity(0.14), pet.tone.hue.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)

                HStack(spacing: 14) {
                    NavigationLink {
                        PetDetailView(pet: pet, initialTab: .upcoming)
                    } label: {
                        Monogram(pet: pet, size: 68, radius: 18)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(pet.name)
                            .font(.system(size: 26, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(Color.bonesInk)
                        StatusPill(status: pet.healthStatus, label: pet.healthStatusLabel)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            HStack(spacing: 6) {
                Text(pet.species.rawValue.capitalized)
                if let breed = pet.breed, !breed.isEmpty {
                    Text("·").foregroundStyle(Color.bonesInkFaint)
                    Text(breed)
                }
                if let age = ageString(for: pet.birthDate) {
                    Text("·").foregroundStyle(Color.bonesInkFaint)
                    Text(age)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                Spacer(minLength: 0)
                Button { onEdit() } label: {
                    Text("Editar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.bonesInkSoft)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Capsule().strokeBorder(Color.bonesRule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(Color.bonesInkSoft)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Próximos eventos")
            HStack(spacing: 10) {
                Group {
                    if let vac = nextVaccine() {
                        KpiCard(
                            icon: "syringe.fill", iconColor: .bonesVaccine,
                            pillLabel: bonesRelativeLabel(for: vac.date),
                            eyebrow: "Próx. vacuna",
                            dateText: bonesShortDate(vac.date),
                            eventName: DoseSeries.splitDoseBase(from: vac.vaccineName),
                            date: vac.date,
                            status: eventStatus(vac.date)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onNavigate(.vaccines) }
                    } else {
                        emptyKpiCard(icon: "syringe.fill", iconColor: .bonesVaccine, label: "Próx. vacuna")
                            .onTapGesture { onNavigate(.vaccines) }
                    }
                }
                Group {
                    if let dew = nextDeworming() {
                        KpiCard(
                            icon: "drop.fill", iconColor: .bonesDeworming,
                            pillLabel: bonesRelativeLabel(for: dew.date),
                            eyebrow: "Próx. desparas.",
                            dateText: bonesShortDate(dew.date),
                            eventName: dew.notes ?? "Desparasitación",
                            date: dew.date,
                            status: eventStatus(dew.date)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onNavigate(.deworming) }
                    } else {
                        emptyKpiCard(icon: "drop.fill", iconColor: .bonesDeworming, label: "Próx. desparas.")
                            .onTapGesture { onNavigate(.deworming) }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Estado")
            VStack(spacing: 0) {
                weightRow
                Divider().background(Color.bonesRule).padding(.horizontal, 14)
                lastVaccineRow
                Divider().background(Color.bonesRule).padding(.horizontal, 14)
                lastDewormingRow
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.bonesPanel)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.bonesRule, lineWidth: 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var weightRow: some View {
        let weights = sortedWeights()
        let last = weights.first
        let (deltaStr, trend): (String?, WeightTrend?) = {
            guard weights.count >= 2 else { return (nil, nil) }
            let diff = weights[0].weightKg - weights[1].weightKg
            if abs(diff) < 0.05 { return ("+0.0", .flat) }
            let sign = diff > 0 ? "+" : ""
            return ("\(sign)\(String(format: "%.1f", diff))", diff > 0 ? .up : .down)
        }()

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.bonesBg)
                    .frame(width: 30, height: 30)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.bonesWeight)
            }
            Text("PESO")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
            Spacer(minLength: 0)
            if let w = last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", w.weightKg))
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.bonesInk)
                    Text("kg")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bonesInkSoft)
                }
                if let ds = deltaStr, let tr = trend {
                    DeltaBadge(delta: ds, trend: tr)
                }
                Text(bonesRelativeLabel(for: w.date))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.bonesInkFaint)
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.bonesInkFaint)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture { onNavigate(.weight) }
    }

    private var lastVaccineRow: some View {
        Group {
            if let lv = lastVaccine() {
                RegRow(
                    icon: "syringe.fill", iconColor: .bonesVaccine,
                    label: "Última vacuna",
                    value: DoseSeries.splitDoseBase(from: lv.vaccineName),
                    meta: bonesShortDate(lv.date)
                )
                .contentShape(Rectangle())
                .onTapGesture { onNavigate(.vaccines) }
            } else {
                RegRow(
                    icon: "syringe.fill", iconColor: .bonesVaccine,
                    label: "Última vacuna", value: "Sin registrar", meta: nil
                )
            }
        }
    }

    private var lastDewormingRow: some View {
        Group {
            if let ld = lastDeworming() {
                RegRow(
                    icon: "drop.fill", iconColor: .bonesDeworming,
                    label: "Última desparas.",
                    value: ld.notes ?? "Desparasitación",
                    meta: bonesShortDate(ld.date)
                )
                .contentShape(Rectangle())
                .onTapGesture { onNavigate(.deworming) }
            } else {
                RegRow(
                    icon: "drop.fill", iconColor: .bonesDeworming,
                    label: "Última desparas.", value: "Sin registrar", meta: nil
                )
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            Text("Eliminar mascota")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bonesOverdue.opacity(0.7))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.bonesInkFaint)
    }

    private func emptyKpiCard(icon: String, iconColor: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.bonesInkFaint)
            Text("Sin programar")
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.bonesInkFaint)
        }
        .contentShape(Rectangle())
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
    }

    private func eventStatus(_ date: Date) -> HealthStatus {
        let now = Date()
        if date < now { return .overdue }
        if date.timeIntervalSince(now) < 7 * 24 * 3600 { return .soon }
        return .ok
    }

    private func nextVaccine() -> Vaccine? {
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func nextDeworming() -> Deworming? {
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func lastVaccine() -> Vaccine? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.isCompleted && $0.date <= now }
    }

    private func lastDeworming() -> Deworming? {
        let now = Date()
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id && $0.isCompleted && $0.date <= now }
    }

    private func sortedWeights() -> [WeightEntry] {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.filter { $0.pet?.id == pet.id }
    }

    private func deletePet() {
        let vacs    = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews    = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        for e in vacs    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in weights where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        context.delete(pet)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - D · Grid (4+ mascotas)

private struct VetProGrid: View {
    @Environment(\.modelContext) private var context
    let pets: [Pet]
    let onEdit: (Pet) -> Void

    @State private var quickAdd: PetQuickAdd?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(pets) { pet in
                    NavigationLink {
                        PetDetailView(pet: pet)
                    } label: {
                        VetProPetCard(pet: pet)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            quickAdd = PetQuickAdd(pet: pet, kind: .vaccine)
                        } label: {
                            Label("Vacuna", systemImage: "syringe.fill")
                        }
                        .tint(pet.tone.hue)

                        Button {
                            quickAdd = PetQuickAdd(pet: pet, kind: .weight)
                        } label: {
                            Label("Peso", systemImage: "scalemass.fill")
                        }
                        .tint(Color.bonesWeight)
                    }
                    .contextMenu {
                        Button("Editar", systemImage: "pencil") { onEdit(pet) }
                        Divider()
                        Button("Eliminar", systemImage: "trash", role: .destructive) { deletePet(pet) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.bonesBg.ignoresSafeArea())
        .sheet(item: $quickAdd) { req in
            EventQuickAddSheet(pet: req.pet, initialKind: req.kind)
        }
    }

    private func deletePet(_ pet: Pet) {
        let vacs    = (try? context.fetch(FetchDescriptor<Vaccine>())) ?? []
        let dews    = (try? context.fetch(FetchDescriptor<Deworming>())) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        for e in vacs    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in dews    where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        for e in weights where e.pet?.id == pet.id { NotificationManager.shared.cancelNotification(id: e.id) }
        context.delete(pet)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
    }
}

// MARK: - PetCard (item de grilla)

private struct VetProPetCard: View {
    @Environment(\.modelContext) private var context
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                Monogram(pet: pet, size: 48, radius: 13)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(pet.name)
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.bonesInk)
                        StatusPill(status: pet.healthStatus, label: pet.healthStatusLabel)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 5) {
                        Text(pet.species.rawValue.capitalized)
                        if let breed = pet.breed, !breed.isEmpty {
                            Text("·").foregroundStyle(Color.bonesRule)
                            Text(breed)
                        }
                        if let age = ageString(for: pet.birthDate) {
                            Text("·").foregroundStyle(Color.bonesRule)
                            Text(age)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.bonesInkSoft)
                    .lineLimit(1)
                }
            }

            // 3-up strip
            HStack(spacing: 8) {
                MiniStat(
                    icon: "syringe.fill", iconColor: .bonesVaccine,
                    label: "Vacuna",
                    value: nextVaccineLabel(),
                    sub: nextVaccineDate()
                )
                MiniStat(
                    icon: "drop.fill", iconColor: .bonesDeworming,
                    label: "Desparas.",
                    value: nextDewormingLabel(),
                    sub: nextDewormingDate()
                )
                MiniStat(
                    icon: "scalemass.fill", iconColor: .bonesWeight,
                    label: "Peso",
                    value: lastWeightLabel(),
                    sub: lastWeightDate()
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.bonesPanel)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.bonesRule, lineWidth: 1))
        )
    }

    private func nextVaccineLabel() -> String {
        guard let v = nextVaccine() else { return "Sin programar" }
        return bonesRelativeLabel(for: v.date).capitalized
    }

    private func nextVaccineDate() -> String? {
        nextVaccine().map { bonesShortDate($0.date) }
    }

    private func nextDewormingLabel() -> String {
        guard let d = nextDeworming() else { return "Sin programar" }
        return bonesRelativeLabel(for: d.date).capitalized
    }

    private func nextDewormingDate() -> String? {
        nextDeworming().map { bonesShortDate($0.date) }
    }

    private func lastWeightLabel() -> String {
        guard let w = lastWeight() else { return "—" }
        return String(format: "%.1f kg", w.weightKg)
    }

    private func lastWeightDate() -> String? {
        lastWeight().map { bonesShortDate($0.date) }
    }

    private func nextVaccine() -> Vaccine? {
        let items = (try? context.fetch(FetchDescriptor<Vaccine>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func nextDeworming() -> Deworming? {
        let items = (try? context.fetch(FetchDescriptor<Deworming>(sortBy: [SortDescriptor(\.date)]))) ?? []
        return items.first { $0.pet?.id == pet.id && !$0.isCompleted }
    }

    private func lastWeight() -> WeightEntry? {
        let items = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        return items.first { $0.pet?.id == pet.id }
    }
}

// MARK: - Previews

private enum PetsListPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Pet.self, Vaccine.self, Deworming.self, WeightEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }

    @discardableResult
    static func seedPets(count: Int, in container: ModelContainer, withEvents: Bool = true) -> [Pet] {
        let ctx = ModelContext(container)
        var result: [Pet] = []
        let namesDogs = ["Loki", "Kira", "Max", "Nala", "Toby", "Luna", "Rocky", "Milo"]
        let namesCats = ["Mishi", "Mía", "Simba", "Olivia", "Leo", "Coco", "Lola", "Chispa"]
        let breedsDogs = ["Husky", "Labrador", "Pastor", "Mestizo", "Beagle"]
        let breedsCats = ["Común", "Siamés", "Persa", "Mestizo"]
        let now = Date()
        let cal = Calendar.current

        for i in 0..<count {
            let isDog = (i % 2 == 0)
            let pet = Pet(
                name: isDog ? namesDogs[i % namesDogs.count] : namesCats[i % namesCats.count],
                species: isDog ? .perro : .gato,
                breed: isDog ? breedsDogs[i % breedsDogs.count] : breedsCats[i % breedsCats.count],
                birthDate: cal.date(byAdding: .year, value: -(1 + i % 6), to: now),
                sex: (i % 3 == 0) ? .male : .female
            )
            ctx.insert(pet)
            result.append(pet)

            if withEvents {
                let offsets: [TimeInterval] = [-20, 9, 35]
                let v = Vaccine(date: now.addingTimeInterval(offsets[i % 3] * 86400), pet: pet,
                                vaccineName: "Polivalente (1/3)")
                if offsets[i % 3] < 0 { v.isCompleted = true }
                ctx.insert(v)
                let d = Deworming(date: now.addingTimeInterval(Double(5 + i * 3) * 86400), pet: pet,
                                  notes: "Pipeta mensual")
                ctx.insert(d)
                let w = WeightEntry(date: now.addingTimeInterval(-Double(3 + i) * 86400), pet: pet,
                                    weightKg: isDog ? 22.5 + Double(i) * 0.3 : 4.1 + Double(i) * 0.1)
                ctx.insert(w)
                if i > 0 {
                    let w2 = WeightEntry(date: now.addingTimeInterval(-Double(20 + i) * 86400), pet: pet,
                                         weightKg: isDog ? 22.2 + Double(i) * 0.3 : 4.0 + Double(i) * 0.1)
                    ctx.insert(w2)
                }
            }
        }
        try? ctx.save()
        return result
    }
}

#Preview("Vacío") {
    PetsListView().modelContainer(PetsListPreviewData.makeContainer())
}

#Preview("1 mascota — Dashboard") {
    let c = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 1, in: c)
    return PetsListView().modelContainer(c)
}

#Preview("3 mascotas — Carrusel") {
    let c = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 3, in: c)
    return PetsListView().modelContainer(c)
}

#Preview("6 mascotas — Grid grande") {
    let c = PetsListPreviewData.makeContainer()
    _ = PetsListPreviewData.seedPets(count: 6, in: c)
    return PetsListView().modelContainer(c)
}

#Preview("Demo Guide — Resumen") {
    let c = PetsListPreviewData.makeContainer()
    let ctx = ModelContext(c)
    ctx.insert(Pet(name: "Marcos", species: .perro, breed: "Demo", sex: .male))
    try? ctx.save()
    UserDefaults.standard.set(true,  forKey: "didChooseDemoPet")
    UserDefaults.standard.set(false, forKey: "didCompleteDemoGuide")
    UserDefaults.standard.set(DemoGuideStep.summary.rawValue, forKey: "demoGuideStep")
    return PetsListView().modelContainer(c)
}

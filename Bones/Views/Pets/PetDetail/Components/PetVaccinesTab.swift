//
//  PetVaccinesTab.swift
//  Bones
//
//  Created by Felipe Duarte on 17/07/25.
//

import SwiftUI
import SwiftData
import UIKit

struct PetVaccinesTab: View {
    @ObservedObject var viewModel: PetDetailViewModel
    @Environment(\.modelContext) private var context

    @State private var showingDeleteDialog = false
    @State private var pendingDelete: Vaccine?

    private var pending: [Vaccine] {
        viewModel.vaccines.filter { !$0.isCompleted }.sorted { $0.date < $1.date }
    }

    private var completed: [Vaccine] {
        viewModel.vaccines.filter { $0.isCompleted }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if viewModel.vaccines.isEmpty {
                ContentUnavailableView("Sin vacunas registradas", systemImage: "syringe")
            } else {
                if !pending.isEmpty {
                    Section("Pendientes") {
                        ForEach(pending) { vac in
                            NavigationLink {
                                EventDetailView(event: vac)
                            } label: {
                                VaccineRow(vac: vac)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    vac.isCompleted = true
                                    vac.completedAt = Date()
                                    NotificationManager.shared.cancelNotification(id: vac.id)
                                    try? context.save()
                                    NotificationCenter.default.post(name: .eventsDidChange, object: nil)
                                    viewModel.fetchEvents()
                                } label: {
                                    Label("Aplicada", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    startDelete(for: vac)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                            .listRowSeparatorTint(Color.bonesRule)
                        }
                    }
                }

                if !completed.isEmpty {
                    Section("Historial") {
                        ForEach(completed) { vac in
                            NavigationLink {
                                EventDetailView(event: vac)
                            } label: {
                                VaccineRow(vac: vac)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    startDelete(for: vac)
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                            .listRowSeparatorTint(Color.bonesRule)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .background(Color.bonesBg)
        .onAppear { viewModel.fetchEvents() }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidChange)) { _ in
            viewModel.fetchEvents()
        }
        .confirmationDialog(
            "¿Eliminar vacuna?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let vac = pendingDelete { deleteSingle(vac) }
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func startDelete(for vac: Vaccine) {
        pendingDelete = vac
        showingDeleteDialog = true
    }

    private func deleteSingle(_ vac: Vaccine) {
        NotificationManager.shared.cancelNotification(id: vac.id)
        context.delete(vac)
        try? context.save()
        NotificationCenter.default.post(name: .eventsDidChange, object: nil)
        viewModel.fetchEvents()
        pendingDelete = nil
        showingDeleteDialog = false
    }
}

// MARK: - Vaccine row

private struct VaccineRow: View {
    let vac: Vaccine

    private var isOverdue: Bool { !vac.isCompleted && vac.date < Date() }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if vac.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.bonesOk)
                } else if isOverdue {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.bonesOverdue)
                } else {
                    Image(systemName: "circle").foregroundStyle(Color.bonesVaccine)
                }
            }
            .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                Text(DoseSeries.splitDoseBase(from: vac.vaccineName))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOverdue ? Color.bonesOverdue : Color.bonesInk)
                HStack(spacing: 5) {
                    Text(vac.date, format: .dateTime.day().month().year())
                        .font(.caption2)
                        .foregroundStyle(Color.bonesInkFaint)
                    if let m = vac.manufacturer, !m.isEmpty {
                        Text("·").font(.caption2).foregroundStyle(Color.bonesInkFaint)
                        Text(m).font(.caption2).foregroundStyle(Color.bonesInkSoft)
                    }
                }
            }

            Spacer()

            if isOverdue {
                RegStatusTag(label: "Vencida", color: .bonesOverdue)
            } else if !vac.isCompleted {
                RegStatusTag(label: bonesRelativeLabel(for: vac.date), color: .bonesVaccine)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct RegStatusTag: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.10)))
    }
}

// MARK: - Previews

#Preview("Vacunas – Diverso") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.seedDiverseVaccines(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Vacunas – Vacío") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.emptyPet(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

#Preview("Solo vencidas") {
    let container = VaccinesPreviewData.makeContainer()
    let pet = VaccinesPreviewData.onlyOverdueVaccines(in: container)
    return PetVaccinesTabPreviewHost(pet: pet)
        .modelContainer(container)
}

private struct PetVaccinesTabPreviewHost: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @StateObject private var vm: PetDetailViewModel

    init(pet: Pet) {
        self.pet = pet
        _vm = StateObject(wrappedValue: PetDetailViewModel(petID: pet.id))
    }

    var body: some View {
        PetVaccinesTab(viewModel: vm)
            .onAppear {
                vm.inject(context: context)
            }
    }
}

private enum VaccinesPreviewData {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Pet.self, Vaccine.self, Deworming.self, WeightEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }

    @discardableResult
    static func emptyPet(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Mishi", species: .gato, breed: "Común", sex: .female)
        ctx.insert(pet)
        try? ctx.save()
        return pet
    }

    @discardableResult
    static func seedDiverseVaccines(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Loki", species: .perro, breed: "Husky", sex: .male)
        ctx.insert(pet)
        let now = Date()
        let v1 = Vaccine(date: now.addingTimeInterval(2 * 24 * 3600), pet: pet,
                         vaccineName: "Rabia", manufacturer: "VetLabs")
        let v2 = Vaccine(date: now.addingTimeInterval(30 * 24 * 3600), pet: pet,
                         vaccineName: "Moquillo", manufacturer: nil)
        let v3 = Vaccine(date: now.addingTimeInterval(-10 * 24 * 3600), pet: pet,
                         vaccineName: "Polivalente", manufacturer: "VetLabs")
        v3.isCompleted = true
        v3.completedAt = v3.date
        let v4 = Vaccine(date: now.addingTimeInterval(-3 * 24 * 3600), pet: pet,
                         vaccineName: "Parvovirus", manufacturer: "")
        [v1, v2, v3, v4].forEach { ctx.insert($0) }
        try? ctx.save()
        return pet
    }

    @discardableResult
    static func onlyOverdueVaccines(in container: ModelContainer) -> Pet {
        let ctx = ModelContext(container)
        let pet = Pet(name: "Rocky", species: .perro, breed: "Boxer", sex: .male)
        ctx.insert(pet)
        let now = Date()
        let v1 = Vaccine(date: now.addingTimeInterval(-7 * 24 * 3600), pet: pet,
                         vaccineName: "Moquillo", manufacturer: "LabX")
        let v2 = Vaccine(date: now.addingTimeInterval(-20 * 24 * 3600), pet: pet,
                         vaccineName: "Rabia", manufacturer: nil)
        [v1, v2].forEach { ctx.insert($0) }
        try? ctx.save()
        return pet
    }
}

// MARK: - Demo seeder (usado en onboarding)

struct DemoSeeder {
    static func seedDemoDog(in container: ModelContainer) -> Pet {
        let context = ModelContext(container)
        return seedDemoDog(in: context)
    }

    static func seedDemoDog(in context: ModelContext) -> Pet {
        let demo = Pet(name: "Marcos", species: .perro, breed: "Demo Breed", sex: .male)
        let demoImage = UIImage(named: "MarcosPhoto")
        if let uiImage = demoImage {
            demo.photoData = uiImage.jpegData(compressionQuality: 0.9)
        }
        context.insert(demo)
        let now = Date()
        let cal = Calendar.current

        let rabiesPast = Vaccine(date: cal.date(byAdding: .month, value: -11, to: now)!,
                                 pet: demo, vaccineName: "Antirrábica")
        rabiesPast.isCompleted = true
        rabiesPast.completedAt = rabiesPast.date
        let rabiesNext = Vaccine(date: cal.date(byAdding: .month, value: 1, to: now)!,
                                 pet: demo, vaccineName: "Antirrábica")

        let polivalente = Vaccine(date: cal.date(byAdding: .month, value: -2, to: now)!,
                                  pet: demo, vaccineName: "Polivalente (DHPPi)")
        polivalente.isCompleted = true
        polivalente.completedAt = polivalente.date

        let lepto = Vaccine(date: cal.date(byAdding: .day, value: 10, to: now)!,
                            pet: demo, vaccineName: "Leptospirosis")

        [rabiesPast, rabiesNext, polivalente, lepto].forEach { context.insert($0) }

        let w1 = WeightEntry(date: cal.date(byAdding: .month, value: -3, to: now)!, pet: demo, weightKg: 8.2)
        let w2 = WeightEntry(date: cal.date(byAdding: .month, value: -2, to: now)!, pet: demo, weightKg: 8.7)
        let w3 = WeightEntry(date: cal.date(byAdding: .month, value: -1, to: now)!, pet: demo, weightKg: 9.1)
        let w4 = WeightEntry(date: cal.date(byAdding: .day, value: -3, to: now)!, pet: demo, weightKg: 9.4)
        [w1, w2, w3, w4].forEach { context.insert($0) }

        try? context.save()
        return demo
    }
}

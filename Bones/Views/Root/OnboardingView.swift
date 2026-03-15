//
//  OnboardingView.swift
//  Bones
//
//  Created by Felipe Duarte on 13/03/26.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Binding var didCompleteOnboarding: Bool

    @Query(sort: \Pet.name) private var pets: [Pet]
    @State private var isPresentingAdd = false
    @AppStorage("didChooseDemoPet") private var didChooseDemoPet: Bool = false
    @AppStorage("demoGuideStep") private var demoGuideStep: Int = 0

    private let primaryColor = Color(red: 0.28, green: 0.63, blue: 0.96)
    private let secondaryColor = Color(red: 0.92, green: 0.96, blue: 1.00)

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 28) {
                    header
                    valueProps
                    actions
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $isPresentingAdd) {
            AddPetSheet()
        }
        .onChange(of: pets.count) { _, _ in
            if !didCompleteOnboarding, !pets.isEmpty {
                completeOnboarding()
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 0.97),
                    Color(red: 0.88, green: 0.94, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.74, green: 0.88, blue: 0.98))
                .frame(width: 280, height: 280)
                .blur(radius: 20)
                .offset(x: -120, y: -140)

            Circle()
                .fill(Color(red: 0.85, green: 0.93, blue: 1.00))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: 140, y: 90)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 96, height: 96)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryColor)
            }

            Text("Bienvenido a Bones")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.black.opacity(0.86))
                .multilineTextAlignment(.center)

            Text("Organiza vacunas, medicamentos y recordatorios sin esfuerzo desde el primer día.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    private var valueProps: some View {
        VStack(spacing: 12) {
            featureRow(icon: "calendar.badge.checkmark", title: "Eventos claros", subtitle: "Fechas próximas y vencidas a la vista.")
            featureRow(icon: "pills.fill", title: "Medicaciones ordenadas", subtitle: "Series y recordatorios sin duplicados.")
            featureRow(icon: "heart.text.square.fill", title: "Historial completo", subtitle: "Peso, vacunas y cuidados en un solo lugar.")
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                isPresentingAdd = true
            } label: {
                Text("Crear mi mascota")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryColor)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }

            Button {
                if pets.isEmpty {
                    _ = DemoSeeder.seedDemoDogWithMedications(in: context)
                }
                didChooseDemoPet = true
                demoGuideStep = DemoGuideStep.summary.rawValue
                completeOnboarding()
            } label: {
                Text("Explorar con Marcos")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(secondaryColor)
                    .foregroundStyle(primaryColor)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(primaryColor.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    private var footer: some View {
        Text("Puedes borrar a Marcos cuando quieras, igual que cualquier otra mascota.")
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.55))
            .multilineTextAlignment(.center)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(primaryColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.8))
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
    }

    private func completeOnboarding() {
        didCompleteOnboarding = true
        Task {
            await NotificationManager.shared.requestAuthorization()
        }
        dismiss()
    }
}

#Preview {
    OnboardingView(didCompleteOnboarding: .constant(false))
        .modelContainer(for: [Pet.self, Medication.self, Vaccine.self, Deworming.self, Grooming.self, WeightEntry.self], inMemory: true)
}

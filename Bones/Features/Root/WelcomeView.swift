import SwiftUI

struct WelcomeView: View {
    let onAddPet: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .symbolEffect(.breathe)
                .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.row) {
                Text("Bones")
                    .font(.largeTitle)
                    .bold()
                Text("Las vacunas y desparasitaciones de tu mascota, siempre a mano.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.row) {
                Label("Cuándo fue la última vez y con qué", systemImage: "clock.arrow.circlepath")
                Label("Cuándo toca de nuevo", systemImage: "calendar")
                Label("Un aviso antes de que se te pase", systemImage: "bell")
            }
            .foregroundStyle(.secondary)

            Spacer()

            Button("Añadir mascota", systemImage: "plus", action: onAddPet)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WelcomeView(onAddPet: {})
}

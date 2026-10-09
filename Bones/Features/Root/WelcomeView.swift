import SwiftUI

struct WelcomeView: View {
    let onAddPet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: Theme.Spacing.section) {
            Spacer()

            Image(systemName: "pawprint.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .symbolEffect(.breathe, isActive: !reduceMotion)
                .accessibilityHidden(true)
                .staggeredAppear(index: 0, isVisible: hasAppeared)

            VStack(spacing: Theme.Spacing.row) {
                Text("Bones")
                    .font(.largeTitle)
                    .bold()
                Text("Las vacunas y desparasitaciones de tu mascota, siempre a mano.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .staggeredAppear(index: 1, isVisible: hasAppeared)

            VStack(alignment: .leading, spacing: Theme.Spacing.row) {
                Label("Cuándo fue la última vez y con qué", systemImage: "clock.arrow.circlepath")
                    .staggeredAppear(index: 2, isVisible: hasAppeared)
                Label("Cuándo toca de nuevo", systemImage: "calendar")
                    .staggeredAppear(index: 3, isVisible: hasAppeared)
                Label("Un aviso antes de que se te pase", systemImage: "bell")
                    .staggeredAppear(index: 4, isVisible: hasAppeared)
            }
            .foregroundStyle(.secondary)

            Spacer()

            Button("Añadir mascota", systemImage: "plus", action: onAddPet)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .staggeredAppear(index: 5, isVisible: hasAppeared)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onAppear(perform: appear)
    }

    private func appear() {
        hasAppeared = true
    }
}

#Preview {
    WelcomeView(onAddPet: {})
}

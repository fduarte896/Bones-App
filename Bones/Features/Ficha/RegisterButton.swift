import SwiftUI

/// El botón principal de la app, siempre al alcance del pulgar.
/// Justo después de guardar se convierte un momento en "Registrado" para confirmar.
struct RegisterButton: View {
    let isConfirming: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Label {
                Text(isConfirming ? "Registrado" : "Registrar")
            } icon: {
                Image(systemName: isConfirming ? "checkmark" : "plus")
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .bold()
        // En modo oscuro el color de acento es claro: el texto blanco no se leería.
        .foregroundStyle(colorScheme == .dark ? .black : .white)
        .animation(Theme.contentChange, value: isConfirming)
        .accessibilityLabel("Registrar")
        .padding(.bottom, 8)
    }
}

#Preview {
    VStack {
        RegisterButton(isConfirming: false, action: {})
        RegisterButton(isConfirming: true, action: {})
    }
}

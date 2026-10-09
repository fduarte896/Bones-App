import SwiftUI

/// El botón principal de la app, siempre al alcance del pulgar.
struct RegisterButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button("Registrar", systemImage: "plus", action: action)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .bold()
            // En modo oscuro el color de acento es claro: el texto blanco no se leería.
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .padding(.bottom, 8)
    }
}

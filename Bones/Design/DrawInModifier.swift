import SwiftUI

/// Revela una gráfica de izquierda a derecha la primera vez que aparece.
/// Con "Reducir movimiento" activado, simplemente aparece con un fundido.
struct DrawInModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                Rectangle()
                    .scaleEffect(x: isRevealed || reduceMotion ? 1 : 0, anchor: .leading)
            }
            .opacity(isRevealed ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 0.9)) {
                    isRevealed = true
                }
            }
    }
}

extension View {
    func drawsIn() -> some View {
        modifier(DrawInModifier())
    }
}

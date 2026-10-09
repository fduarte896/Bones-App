import SwiftUI

/// Hace que un texto cambie con transición de dígitos en vez de saltar.
/// Con "Reducir movimiento" activado, se funde.
struct ChangingTextModifier<Value: Equatable>: ViewModifier {
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(Theme.contentChange, value: value)
    }
}

extension View {
    /// Anima el cambio de este texto cada vez que cambia `value`.
    func changingText(_ value: some Equatable) -> some View {
        modifier(ChangingTextModifier(value: value))
    }
}

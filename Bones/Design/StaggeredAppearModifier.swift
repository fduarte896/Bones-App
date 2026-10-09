import SwiftUI

/// Hace entrar un elemento con un pequeño retraso según su posición, para que
/// una pantalla se componga pieza a pieza en lugar de aparecer de golpe.
struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 14)
            .animation(.smooth(duration: 0.5).delay(Double(index) * 0.09), value: isVisible)
    }
}

extension View {
    func staggeredAppear(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredAppearModifier(index: index, isVisible: isVisible))
    }
}

import SwiftUI

/// Medidas y animaciones compartidas, para que toda la app se sienta igual.
enum Theme {
    enum AvatarSize {
        static let chip = 24.0
        static let header = 60.0
        static let form = 112.0
    }

    enum Spacing {
        static let tight = 2.0
        static let row = 12.0
        static let section = 24.0
    }

    /// Para cambios de contenido: cambiar de mascota, aparecer un pendiente.
    static let contentChange: Animation = .snappy(duration: 0.35)
}

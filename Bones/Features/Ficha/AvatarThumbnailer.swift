import SwiftUI

/// Decodifica las fotos de las mascotas una sola vez y a tamaño de avatar,
/// en lugar de decodificar la foto completa cada vez que se dibuja una vista.
@MainActor
final class AvatarThumbnailer {
    static let shared = AvatarThumbnailer()

    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for data: Data, key: String, pointSize: Double, scale: Double) async -> UIImage? {
        let cacheKey = "\(key)-\(data.count)-\(Int(pointSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) { return cached }

        let side = pointSize * scale
        guard let image = UIImage(data: data),
              let thumbnail = await image.byPreparingThumbnail(ofSize: image.size.aspectFilling(side: side)) else {
            return nil
        }
        cache.setObject(thumbnail, forKey: cacheKey)
        return thumbnail
    }
}

private extension CGSize {
    /// El tamaño más pequeño con estas proporciones que cubre un cuadrado de lado `side`.
    func aspectFilling(side: Double) -> CGSize {
        let shortest = min(width, height)
        guard shortest > 0 else { return CGSize(width: side, height: side) }
        let factor = side / shortest
        return CGSize(width: width * factor, height: height * factor)
    }
}

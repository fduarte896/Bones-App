import SwiftUI

/// Reduce las fotos antes de guardarlas: la cámara produce imágenes mucho más
/// grandes de lo que hace falta para leer una receta o mostrar un avatar.
enum ImageDownscaler {
    static func jpegData(from data: Data, maxDimension: Double, quality: Double = 0.8) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }
        let factor = maxDimension / longest
        let target = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let scaled = await image.byPreparingThumbnail(ofSize: target)
        return (scaled ?? image).jpegData(compressionQuality: quality)
    }
}

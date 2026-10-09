import SwiftUI

struct PetAvatar: View {
    let pet: Pet
    let size: Double

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(.tint.quaternary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: pet.species.symbolName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.26)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        // Al cambiar de mascota, la foto anterior se desvanece en lugar de saltar.
        .id(pet.id)
        .transition(.blurReplace)
        .accessibilityHidden(true)
        .task(id: PhotoKey(petID: pet.id, byteCount: pet.photoData?.count)) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let data = pet.photoData else {
            image = nil
            return
        }
        let thumbnail = await AvatarThumbnailer.shared.thumbnail(
            for: data, key: pet.id.uuidString, pointSize: size, scale: displayScale
        )
        withAnimation(.default) { image = thumbnail }
    }

    private struct PhotoKey: Hashable {
        let petID: UUID
        let byteCount: Int?
    }
}

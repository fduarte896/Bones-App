import SwiftUI
import PhotosUI

struct PetPhotoPicker: View {
    @Binding var photoData: Data?
    let species: Species

    @State private var pickedItem: PhotosPickerItem?
    @State private var preview: UIImage?

    var body: some View {
        VStack(spacing: Theme.Spacing.row) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(.tint.quaternary)
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: species.symbolName)
                            .resizable()
                            .scaledToFit()
                            .padding(Theme.AvatarSize.form * 0.28)
                            .foregroundStyle(.tint)
                    }
                }
                .frame(width: Theme.AvatarSize.form, height: Theme.AvatarSize.form)
                .clipShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(photoData == nil ? "Añadir foto" : "Cambiar foto")

            if photoData != nil {
                Button("Quitar foto", role: .destructive, action: removePhoto)
                    .font(.subheadline)
            } else {
                Text("Toca para añadir una foto")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: photoData?.count) {
            preview = photoData.flatMap(UIImage.init(data:))
        }
        .task(id: pickedItem) {
            guard let pickedItem, let data = try? await pickedItem.loadTransferable(type: Data.self) else { return }
            photoData = await ImageDownscaler.jpegData(from: data, maxDimension: 1024) ?? data
        }
    }

    private func removePhoto() {
        photoData = nil
        pickedItem = nil
    }
}

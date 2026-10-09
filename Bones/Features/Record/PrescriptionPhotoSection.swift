import SwiftUI
import PhotosUI

/// Foto opcional de la receta o del carnet, y notas libres.
struct PrescriptionPhotoSection: View {
    @Binding var photoData: Data?
    @Binding var notes: String

    @State private var preview: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var cameraData: Data?

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Section {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 240)
                    .clipShape(.rect(cornerRadius: 12))
                    .accessibilityLabel("Foto de la receta")
                Button("Quitar foto", systemImage: "trash", role: .destructive, action: removePhoto)
            } else if canUseCamera {
                Menu {
                    Button("Tomar foto", systemImage: "camera", action: showCamera)
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("Elegir de Fotos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Añadir foto de la receta", systemImage: "camera")
                }
                .fullScreenCover(isPresented: $isShowingCamera) {
                    CameraPicker(imageData: $cameraData)
                        .ignoresSafeArea()
                }
            } else {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Añadir foto de la receta", systemImage: "photo.on.rectangle")
                }
            }

            // Las tareas van en esta fila porque es la única que siempre está en pantalla:
            // un modificador puesto en la `Section` se repetiría en cada una de sus filas.
            TextField("Notas", text: $notes, axis: .vertical)
                .lineLimit(1...5)
                .task(id: photoData?.count) {
                    preview = photoData.flatMap(UIImage.init(data:))
                }
                .task(id: pickedItem) {
                    guard let pickedItem else { return }
                    await store(try? await pickedItem.loadTransferable(type: Data.self))
                }
                .task(id: cameraData?.count) {
                    await store(cameraData)
                }
        }
    }

    private func store(_ data: Data?) async {
        guard let data else { return }
        photoData = await ImageDownscaler.jpegData(from: data, maxDimension: 2000) ?? data
    }

    private func removePhoto() {
        photoData = nil
        pickedItem = nil
        cameraData = nil
    }

    private func showCamera() {
        isShowingCamera = true
    }
}

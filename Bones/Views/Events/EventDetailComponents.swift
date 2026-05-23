import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Header

struct EventDetailHeader: View {
    let pet: Pet?
    let title: String
    let icon: String
    let isCompleted: Bool
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            if let data = pet?.photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "pawprint"))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(isCompleted ? "Completado" : "Pendiente")
                        .foregroundStyle(isCompleted ? .green : .orange)
                    Text(date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pet {
                    Text("🐾 \(pet.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - PrescriptionSection

struct PrescriptionSection: View {
    @Binding var imageData: Data?
    var onChange: () -> Void = {}

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingFullImage = false

    var body: some View {
        Section("Prescripción") {
            if let data = imageData, let ui = UIImage(data: data) {
                VStack(spacing: 8) {
                    Button { showingFullImage = true } label: {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                    HStack {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Reemplazar", systemImage: "photo")
                        }
                        Button(role: .destructive) {
                            imageData = nil
                            onChange()
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Spacer()
                        if let dataToShare = imageData {
                            ShareLink(item: dataToShare, preview: .init("Prescripción", image: Image(uiImage: ui)))
                        }
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                HStack {
                    Button { showingCamera = true } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Elegir de la fototeca", systemImage: "photo.on.rectangle")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    imageData = data
                    onChange()
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(imageData: $imageData) { onChange() }
        }
        .fullScreenCover(isPresented: $showingFullImage) {
            if let data = imageData, let ui = UIImage(data: data) {
                ZoomableImageView(image: ui) { showingFullImage = false }
            }
        }
    }
}

// MARK: - ZoomableImageView

struct ZoomableImageView: View {
    let image: UIImage
    var onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture().onChanged { value in
                        scale = max(1.0, value)
                    })
                    .gesture(DragGesture().onChanged { value in
                        offset = value.translation
                    }.onEnded { _ in
                        if scale == 1 { offset = .zero }
                    })
                    .background(Color.black.opacity(0.98))
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }
}

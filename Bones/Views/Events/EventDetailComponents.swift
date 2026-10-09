import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Header

struct EventDetailHeader: View {
    let pet: Pet?
    let title: String
    let accentColor: Color
    let isCompleted: Bool
    let date: Date

    private var statusHealth: HealthStatus {
        if isCompleted { return .ok }
        if date < Date() { return .overdue }
        return .soon
    }

    private var statusLabel: String {
        if isCompleted { return "Completado" }
        if date < Date() { return "Vencido" }
        return "Pendiente"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            petAvatar
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bonesInk)
                    .lineLimit(2)
                if let pet {
                    Text(pet.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.bonesInkSoft)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(accentColor)
                    Text(bonesShortDate(date))
                        .font(.caption)
                        .foregroundStyle(Color.bonesInkSoft)
                    Spacer()
                    StatusPill(status: statusHealth, label: statusLabel)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var petAvatar: some View {
        if let pet, let data = pet.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        } else if let pet {
            Monogram(pet: pet, size: 54, radius: 13)
        } else {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.bonesRuleSoft)
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(Color.bonesInkFaint)
                )
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

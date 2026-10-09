import SwiftUI

struct Monogram: View {
    let pet: Pet
    var size: CGFloat = 48
    var radius: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(pet.tone.hue)
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.13))
                .frame(width: size * 0.65, height: size * 0.65)
            Text(pet.name.prefix(1).uppercased())
                .font(.system(size: size * 0.40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

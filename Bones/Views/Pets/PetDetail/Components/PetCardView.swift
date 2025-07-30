//
//  PetCardView.swift
//  Bones
//
//  Created by Felipe Duarte on 23/07/25.
//
import SwiftUI

struct PetCardView: View {
    let pet: Pet
    let nextEventDate: Date?      // solo la fecha

    var body: some View {
        VStack(spacing: 8) {
            // Foto circular o placeholder
            Group {
                if let data = pet.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color(.systemGray6))
            .clipShape(Circle())

            // Nombre
            Text(pet.name)
                .font(.headline)
                .lineLimit(1)

            // Próxima fecha (opcional)
            if let date = nextEventDate {
                HStack{
                    Text("Sig. evento:")
                    Text(date, format: .dateTime.day().month())
                }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sin eventos")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)                         // se adapta a la columna
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}



////  PetCardView_Previews.swift
//import SwiftUI
//
//#Preview("Foto + evento") {
//    let sample = Pet(
//        name: "Loki",
//        species: .dog,
//        breed: "Husky",
//        birthDate: Calendar.current.date(from: DateComponents(year: 2021, month: 3, day: 14)),
//        sex: .male,
//        color: "Blanco"
//    )
//    // Carga una imagen de ejemplo del sistema
//    if let img = UIImage(systemName: "dog.fill")?.withRenderingMode(.alwaysOriginal),
//       let data = img.pngData() {
//        sample.photoData = data
//    }
//    PetCardView(pet: sample, nextEventDate: .now.addingTimeInterval(86_400))
//        .previewLayout(.sizeThatFits)
//        .padding()
//}
//
//#Preview("Sin foto · sin evento · Dark") {
//    let sample = Pet(
//        name: "Mía",
//        species: .cat,
//        breed: "Criolla",
//        birthDate: Calendar.current.date(from: DateComponents(year: 2020, month: 11, day: 2)),
//        sex: .female,
//        color: "Gris"
//    )
//    PetCardView(pet: sample, nextEvent: nil)
//        .previewLayout(.sizeThatFits)
//        .padding()
//        .environment(\.colorScheme, .dark)
//}
//

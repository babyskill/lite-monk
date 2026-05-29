import SwiftUI

/// The pet in the floating window: a built-in vector sprite or an imported
/// spritesheet pet, reacting to the current mood.
struct PetView: View {
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared

    var body: some View {
        content
            .frame(width: 120, height: 120)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        switch pet.selection {
        case .builtin(let kind):
            PetSpriteView(kind: kind, mood: pet.mood)
        case .imported(let id):
            if let pack = imagePets.pack(id: id) {
                ImageSpriteView(frames: pack.frames, mood: pet.mood)
            } else {
                PetSpriteView(kind: .blob, mood: pet.mood)
            }
        }
    }
}

import AppKit
import LiteMonkCore

/// Loads and imports spritesheet pet packs from `~/.litemonk/pets/`.
@MainActor
final class ImagePetStore: ObservableObject {
    static let shared = ImagePetStore()

    @Published private(set) var packs: [ImagePetPack] = []

    private var petsDir: URL {
        URL(fileURLWithPath: LiteMonkPaths.baseDir).appendingPathComponent("pets")
    }

    func pack(id: String) -> ImagePetPack? {
        packs.first { $0.id == id }
    }

    /// Deletes an installed pet's folder from disk and reloads.
    func delete(_ pack: ImagePetPack) {
        try? FileManager.default.removeItem(at: pack.directory)
        reload()
    }

    func reload() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: petsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            packs = []
            return
        }
        packs = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .compactMap { SpriteSlicer.loadPack(directory: $0) }
            .sorted { $0.displayName < $1.displayName }
    }
}

import Foundation
import AgentPetCore

struct RemotePet: Decodable, Identifiable {
    let slug: String
    let displayName: String
    let kind: String
    let submittedBy: String
    let spritesheetUrl: String
    let petJsonUrl: String

    var id: String { slug }
}

/// Loads the online pet library and downloads packs into `~/.agentpet/pets/`.
@MainActor
final class PetBrowser: ObservableObject {
    @Published var pets: [RemotePet] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var query = ""
    @Published var downloading: Set<String> = []
    @Published var installed: Set<String> = []

    // Internal source of the library (not surfaced in the UI).
    private static let manifestURL = URL(string: "https://petdex.crafter.run/api/manifest")!

    private struct Manifest: Decodable { let pets: [RemotePet] }
    private struct PackMeta: Decodable { let id: String?; let spritesheetPath: String }

    var results: [RemotePet] {
        guard !query.isEmpty else { return pets }
        let q = query.lowercased()
        return pets.filter { $0.displayName.lowercased().contains(q) || $0.slug.contains(q) }
    }

    func loadIfNeeded() {
        guard pets.isEmpty, !isLoading else { return }
        isLoading = true
        errorText = nil
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: Self.manifestURL)
                let manifest = try JSONDecoder().decode(Manifest.self, from: data)
                self.pets = manifest.pets
            } catch {
                self.errorText = "Couldn't load the pet library. Check your connection."
            }
            self.isLoading = false
        }
    }

    func download(_ pet: RemotePet) {
        guard !downloading.contains(pet.slug) else { return }
        downloading.insert(pet.slug)
        Task {
            await performDownload(pet)
            self.downloading.remove(pet.slug)
        }
    }

    private func performDownload(_ pet: RemotePet) async {
        do {
            let fm = FileManager.default
            let dir = URL(fileURLWithPath: AgentPetPaths.baseDir)
                .appendingPathComponent("pets").appendingPathComponent(pet.slug)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            guard let petJsonURL = URL(string: pet.petJsonUrl),
                  let sheetURL = URL(string: pet.spritesheetUrl) else { return }

            let (petJsonData, _) = try await URLSession.shared.data(from: petJsonURL)
            let meta = try JSONDecoder().decode(PackMeta.self, from: petJsonData)
            try petJsonData.write(to: dir.appendingPathComponent("pet.json"))

            let (sheetData, _) = try await URLSession.shared.data(from: sheetURL)
            try sheetData.write(to: dir.appendingPathComponent(meta.spritesheetPath))

            ImagePetStore.shared.reload()
            installed.insert(pet.slug)
            if let id = meta.id { PetController.shared.selectedPetID = id }
        } catch {
            errorText = "Download failed for \(pet.displayName)."
        }
    }
}

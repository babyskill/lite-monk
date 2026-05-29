import AppKit
import AgentPetCore

/// Loads and imports spritesheet pet packs from `~/.agentpet/pets/`.
@MainActor
final class ImagePetStore: ObservableObject {
    static let shared = ImagePetStore()

    @Published private(set) var packs: [ImagePetPack] = []

    private var petsDir: URL {
        URL(fileURLWithPath: AgentPetPaths.baseDir).appendingPathComponent("pets")
    }

    func pack(id: String) -> ImagePetPack? {
        packs.first { $0.id == id }
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

    /// Imports a pet from a folder (containing pet.json) or a `.zip` of one.
    /// Returns the imported pack's id, or nil on failure.
    @discardableResult
    func importPack(from source: URL) -> String? {
        let fm = FileManager.default
        try? fm.createDirectory(at: petsDir, withIntermediateDirectories: true)

        let sourceDir: URL
        var temp: URL?
        if source.pathExtension.lowercased() == "zip" {
            guard let unzipped = unzip(source) else { return nil }
            temp = unzipped
            sourceDir = packRoot(in: unzipped) ?? unzipped
        } else {
            sourceDir = source
        }
        defer { if let temp { try? fm.removeItem(at: temp) } }

        guard let pack = SpriteSlicer.loadPack(directory: sourceDir) else { return nil }
        let dest = petsDir.appendingPathComponent(pack.id)
        try? fm.removeItem(at: dest)
        do {
            try fm.copyItem(at: sourceDir, to: dest)
        } catch {
            return nil
        }
        reload()
        return pack.id
    }

    /// Unzips into a temporary directory and returns it.
    private func unzip(_ zip: URL) -> URL? {
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("agentpet-import-\(zip.lastPathComponent)")
        try? fm.removeItem(at: dest)
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zip.path, "-d", dest.path]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        return process.terminationStatus == 0 ? dest : nil
    }

    /// Finds the directory containing pet.json (handles zips with a wrapper folder).
    private func packRoot(in directory: URL) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.appendingPathComponent("pet.json").path) {
            return directory
        }
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        for entry in entries where (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            if fm.fileExists(atPath: entry.appendingPathComponent("pet.json").path) {
                return entry
            }
        }
        return nil
    }
}

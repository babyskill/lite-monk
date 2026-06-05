import Foundation
import AgentPetCore

enum PetdexError: Error { case badStatus(Int) }

/// Petdex's asset CDN added hotlink protection: requests without a Referer from
/// its own site get 403, which broke all pet downloads. We're a documented
/// Petdex interop client, so we send the expected Referer.
enum PetdexAssets {
    static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("https://petdex.crafter.run/", forHTTPHeaderField: "Referer")
        return r
    }

    /// Fetches an asset, retrying transient rate-limits (429) and server errors
    /// with backoff. Throws on a non-success status so callers never write an
    /// error body (e.g. a 429 "error code" page) to disk as if it were a sheet.
    static func data(_ url: URL) async throws -> Data {
        var lastStatus = 0
        for attempt in 0..<3 {
            let (data, resp) = try await URLSession.shared.data(for: request(url))
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 200
            if (200..<300).contains(code) { return data }
            lastStatus = code
            guard code == 429 || code >= 500, attempt < 2 else { break }
            try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 900_000_000)
        }
        throw PetdexError.badStatus(lastStatus)
    }
}

/// Downloads a pet pack (pet.json + spritesheet) into `~/.agentpet/pets/<slug>/`.
/// Shared by the Browse gallery and first-run onboarding.
enum PetInstaller {
    private struct PackMeta: Decodable { let id: String?; let spritesheetPath: String }

    /// Returns the installed pack's id (pet.json `id`); throws on failure so the
    /// caller can show a meaningful message.
    @discardableResult
    static func download(slug: String, petJsonURL: URL, spritesheetURL: URL) async throws -> String {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: AgentPetPaths.baseDir)
            .appendingPathComponent("pets").appendingPathComponent(slug)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let petJsonData = try await PetdexAssets.data(petJsonURL)
        let meta = try JSONDecoder().decode(PackMeta.self, from: petJsonData)
        try petJsonData.write(to: dir.appendingPathComponent("pet.json"))

        let sheetData = try await PetdexAssets.data(spritesheetURL)
        try sheetData.write(to: dir.appendingPathComponent(meta.spritesheetPath))

        return meta.id ?? slug
    }

    /// A user-facing reason for a failed download.
    static func message(for error: Error, pet: String) -> String {
        if case PetdexError.badStatus(let code) = error, code == 429 {
            return "Petdex is rate-limiting downloads right now. Wait a moment and tap Get again."
        }
        return "Couldn't download \(pet). Check your connection and try again."
    }
}

/// Installs a starter pet on the very first launch so the app isn't empty.
@MainActor
enum DefaultPetBootstrap {
    private static let triedKey = "agentpet.defaultPetTried"
    private static let manifestURL = URL(string: "https://petdex.crafter.run/api/manifest")!
    /// Preferred starter (a non-franchise original); falls back to any pet.
    private static let preferredSlug = "boba"

    struct Entry: Decodable { let slug: String; let spritesheetUrl: String; let petJsonUrl: String }
    private struct Manifest: Decodable { let pets: [Lenient<Entry>] }

    static func installIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: triedKey) else { return }
        guard ImagePetStore.shared.packs.isEmpty, PetController.shared.selectedPetID == nil else {
            d.set(true, forKey: triedKey)
            return
        }
        d.set(true, forKey: triedKey)   // attempt once, even if offline

        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: manifestURL),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return }
            let pets = manifest.pets.compactMap(\.value)
            let pick = pets.first { $0.slug == preferredSlug } ?? pets.first
            guard let pick,
                  let petJsonURL = URL(string: pick.petJsonUrl),
                  let sheetURL = URL(string: pick.spritesheetUrl) else { return }

            let id = try? await PetInstaller.download(slug: pick.slug, petJsonURL: petJsonURL, spritesheetURL: sheetURL)
            ImagePetStore.shared.reload()
            if let id, PetController.shared.selectedPetID == nil {
                PetController.shared.selectedPetID = id
            }
        }
    }
}

/// Tolerant decode wrapper: a malformed element yields nil instead of failing.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) { value = try? T(from: decoder) }
}

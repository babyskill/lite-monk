import Combine
import Foundation
import LiteMonkCore

struct DhammapadaVerse: Codable, Equatable, Identifiable {
    var id: String
    var chapterNumber: Int
    var verseNumber: Int
    var translations: [String: Translation]

    struct Translation: Codable, Equatable {
        var chapterTitle: String
        var text: String
        var translator: String
        var source: String
        var voice: String?

        init(chapterTitle: String, text: String, translator: String = "", source: String = "", voice: String? = nil) {
            self.chapterTitle = chapterTitle
            self.text = text
            self.translator = translator
            self.source = source
            self.voice = voice
        }
    }

    init(
        id: String = UUID().uuidString,
        chapterNumber: Int,
        verseNumber: Int,
        translations: [String: Translation]
    ) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        
        var updated = translations
        for (lang, trans) in translations {
            if lang == "vi", trans.voice == nil {
                var t = trans
                t.voice = "verse-\(chapterNumber)-\(verseNumber)"
                updated[lang] = t
            }
        }
        self.translations = updated
    }

    static var blank: DhammapadaVerse {
        DhammapadaVerse(
            chapterNumber: 1,
            verseNumber: 1,
            translations: [
                "vi": Translation(chapterTitle: "Phẩm mới", text: "", translator: "", source: "")
            ]
        )
    }

    func normalized() -> DhammapadaVerse {
        var normalized = self
        var normTranslations = [String: Translation]()
        for (lang, trans) in translations {
            normTranslations[lang] = Translation(
                chapterTitle: trans.chapterTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                text: trans.text.trimmingCharacters(in: .whitespacesAndNewlines),
                translator: trans.translator.trimmingCharacters(in: .whitespacesAndNewlines),
                source: trans.source.trimmingCharacters(in: .whitespacesAndNewlines),
                voice: trans.voice?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        normalized.translations = normTranslations
        return normalized
    }

    static func nextID() -> String { UUID().uuidString }

    // Hand-coded decode to generate missing ID.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decodeIfPresent(String.self, forKey: .id) ?? Self.nextID()
        let chapterNumber = try c.decode(Int.self, forKey: .chapterNumber)
        let verseNumber = try c.decode(Int.self, forKey: .verseNumber)
        let translations = try c.decode([String: Translation].self, forKey: .translations)
        self.init(
            id: id,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            translations: translations
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case chapterNumber
        case verseNumber
        case translations
    }
}

// Multilingual computed property fallbacks
extension DhammapadaVerse {
    @MainActor
    var currentTranslation: Translation {
        let langCode = AppLanguage.shared.lang.rawValue
        let code: String
        if langCode == "system" {
            code = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            code = langCode
        }
        
        // 1. Exact match for chosen language code (e.g., "vi", "en")
        if let trans = translations[code] {
            return trans
        }
        
        // 2. Base code prefix match (e.g., "zh-Hans" -> "zh")
        let shortCode = code.split(separator: "-").first.map(String.init) ?? code
        if let trans = translations[shortCode] {
            return trans
        }

        // 3. Fallback to English ("en")
        if code != "en", let trans = translations["en"] {
            return trans
        }
        if shortCode != "en", let trans = translations["en"] {
            return trans
        }
        
        // 4. Fallback to Vietnamese ("vi")
        if code != "vi", let trans = translations["vi"] {
            return trans
        }
        
        // 5. Hard fallback to any translation present
        return translations.values.first ?? Translation(chapterTitle: "", text: "", translator: "", source: "")
    }

    @MainActor var chapterTitle: String { currentTranslation.chapterTitle }
    @MainActor var text: String { currentTranslation.text }
    @MainActor var translator: String { currentTranslation.translator }
    @MainActor var source: String { currentTranslation.source }
    @MainActor var voice: String? { currentTranslation.voice }
}

struct LegacyDhammapadaVerse: Codable {
    var id: String
    var chapterNumber: Int
    var chapterTitle: String
    var verseNumber: Int
    var text: String
    var translator: String
    var source: String
    
    func toMultilingual() -> DhammapadaVerse {
        return DhammapadaVerse(
            id: id,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            translations: [
                "vi": DhammapadaVerse.Translation(
                    chapterTitle: chapterTitle,
                    text: text,
                    translator: translator,
                    source: source
                )
            ]
        )
    }
}

@MainActor
final class DhammapadaStore: ObservableObject {
    static let shared = DhammapadaStore()

    @Published private(set) var verses: [DhammapadaVerse]

    init(bundle: Bundle = .module) {
        verses = Self.loadVerses(from: bundle)
    }

    private static var storageURL: URL {
        URL(fileURLWithPath: LiteMonkPaths.baseDir)
            .appendingPathComponent("dhammapada-custom.json")
    }

    private static var legacyStorageURL: URL {
        URL(fileURLWithPath: LiteMonkPaths.baseDir)
            .appendingPathComponent("dhammapada-custom.vi.json")
    }

    private static func loadVerses(from bundle: Bundle) -> [DhammapadaVerse] {
        if let custom = loadCustom(), !custom.isEmpty {
            return custom
        }
        return loadBundled(from: bundle)
    }

    @discardableResult
    func upsert(_ verse: DhammapadaVerse) -> DhammapadaVerse {
        var fixed = verse.normalized()
        if fixed.id.isEmpty { fixed.id = DhammapadaVerse.nextID() }

        if let idx = verses.firstIndex(where: { $0.id == fixed.id }) {
            verses[idx] = fixed
            persist()
            return fixed
        }

        verses.append(fixed)
        persist()
        return fixed
    }

    func remove(id: String) {
        let before = verses.count
        verses.removeAll { $0.id == id }
        guard before != verses.count else { return }
        persist()
    }

    func sorted(_ query: String) -> [DhammapadaVerse] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return verses }
        return verses.filter {
            String($0.chapterNumber).contains(q)
            || $0.chapterTitle.lowercased().contains(q)
            || String($0.verseNumber).contains(q)
            || $0.text.lowercased().contains(q)
            || $0.translator.lowercased().contains(q)
            || $0.source.lowercased().contains(q)
        }
    }

    private func persist() {
        do {
            let dir = Self.storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(verses)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("[LiteMonk] Failed saving Dhammapada data: \(error.localizedDescription)")
        }
    }

    private static func loadCustom() -> [DhammapadaVerse]? {
        let url = storageURL
        let legacyUrl = legacyStorageURL
        
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let verses = try? JSONDecoder().decode([DhammapadaVerse].self, from: data) {
                return verses
            }
        }
        
        // Auto-migration from old vi-only custom file
        if FileManager.default.fileExists(atPath: legacyUrl.path) {
            if let data = try? Data(contentsOf: legacyUrl),
               let legacyVerses = try? JSONDecoder().decode([LegacyDhammapadaVerse].self, from: data) {
                let migrated = legacyVerses.map { $0.toMultilingual() }
                do {
                    let dir = url.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let newData = try encoder.encode(migrated)
                    try newData.write(to: url, options: .atomic)
                    try? FileManager.default.removeItem(at: legacyUrl)
                } catch {
                    print("[LiteMonk] Failed to migrate legacy custom verses: \(error)")
                }
                return migrated
            }
        }
        return nil
    }

    private static func loadBundled(from bundle: Bundle) -> [DhammapadaVerse] {
        guard let url = bundle.url(forResource: "Dhammapada", withExtension: "json") else {
            return fallbackVerses
        }

        do {
            let data = try Data(contentsOf: url)
            let verses = try JSONDecoder().decode([DhammapadaVerse].self, from: data)
            return verses.isEmpty ? fallbackVerses : verses
        } catch {
            print("[LiteMonk] Failed to load bundled Dhammapada: \(error)")
            return fallbackVerses
        }
    }

    // Download, unzip, and import Dhammapada JSON translation files from a GitHub repository ZIP.
    func updateFromGitHub(zipURL: URL) async throws {
        let session = URLSession.shared
        let (localURL, response) = try await session.download(from: zipURL)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "LiteMonk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to download ZIP file. Status code is not 200."])
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Native unzip on macOS using Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", localURL.path, "-d", tempDir.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "LiteMonk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unzip process failed."])
        }
        
        // Scan for all JSON translation files (.json) recursively
        var loadedTranslations = [String: [Int: [Int: DhammapadaVerse.Translation]]]() // langCode -> [chapterNumber -> [verseNumber -> Translation]]
        
        func scanDirectory(at url: URL) throws {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for item in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        try scanDirectory(at: item)
                    } else if item.pathExtension == "json" {
                        let filename = item.deletingPathExtension().lastPathComponent.lowercased()
                        // Skip system files
                        guard filename.count <= 8, !["package", "tsconfig", "package-lock", "manifest"].contains(filename) else {
                            continue
                        }
                        
                        if let data = try? Data(contentsOf: item) {
                            struct SimpleVerse: Codable {
                                var chapterNumber: Int
                                var chapterTitle: String
                                var verseNumber: Int
                                var text: String
                                var translator: String?
                                var source: String?
                            }
                            
                            // Try parsing as simple single-language verse array
                            if let simpleVerses = try? JSONDecoder().decode([SimpleVerse].self, from: data) {
                                var langDict = loadedTranslations[filename] ?? [Int: [Int: DhammapadaVerse.Translation]]()
                                for sv in simpleVerses {
                                    var chap = langDict[sv.chapterNumber] ?? [Int: DhammapadaVerse.Translation]()
                                    chap[sv.verseNumber] = DhammapadaVerse.Translation(
                                        chapterTitle: sv.chapterTitle,
                                        text: sv.text,
                                        translator: sv.translator ?? "",
                                        source: sv.source ?? ""
                                    )
                                    langDict[sv.chapterNumber] = chap
                                }
                                loadedTranslations[filename] = langDict
                            } else if let multiVerses = try? JSONDecoder().decode([DhammapadaVerse].self, from: data) {
                                // Try parsing as fully multilingual array (Dhammapada.json layout)
                                for mv in multiVerses {
                                    for (lCode, trans) in mv.translations {
                                        var langDict = loadedTranslations[lCode] ?? [Int: [Int: DhammapadaVerse.Translation]]()
                                        var chap = langDict[mv.chapterNumber] ?? [Int: DhammapadaVerse.Translation]()
                                        chap[mv.verseNumber] = trans
                                        langDict[mv.chapterNumber] = chap
                                        loadedTranslations[lCode] = langDict
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        try scanDirectory(at: tempDir)
        
        // Clean up
        try? fileManager.removeItem(at: tempDir)
        try? fileManager.removeItem(at: localURL)
        
        guard !loadedTranslations.isEmpty else {
            throw NSError(domain: "LiteMonk", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid translation JSON files found in ZIP."])
        }
        
        // Merge translations by chapterNumber and verseNumber
        var allVersesKeys = Set<String>() // "chapter-verse"
        var keysToNumbers = [String: (Int, Int)]()
        
        for (_, langDict) in loadedTranslations {
            for (chapNum, chap) in langDict {
                for (verseNum, _) in chap {
                    let key = "\(chapNum)-\(verseNum)"
                    allVersesKeys.insert(key)
                    keysToNumbers[key] = (chapNum, verseNum)
                }
            }
        }
        
        var mergedVerses = [DhammapadaVerse]()
        for key in allVersesKeys.sorted(by: { k1, k2 in
            let (c1, v1) = keysToNumbers[k1]!
            let (c2, v2) = keysToNumbers[k2]!
            if c1 != c2 { return c1 < c2 }
            return v1 < v2
        }) {
            let (chapNum, verseNum) = keysToNumbers[key]!
            var transMap = [String: DhammapadaVerse.Translation]()
            
            for (lCode, langDict) in loadedTranslations {
                if let trans = langDict[chapNum]?[verseNum] {
                    transMap[lCode] = trans
                }
            }
            
            let newVerse = DhammapadaVerse(
                id: "verse-\(chapNum)-\(verseNum)",
                chapterNumber: chapNum,
                verseNumber: verseNum,
                translations: transMap
            )
            mergedVerses.append(newVerse)
        }
        
        if !mergedVerses.isEmpty {
            self.verses = mergedVerses
            persist()
        }
    }

    private static let fallbackVerses: [DhammapadaVerse] = [
        DhammapadaVerse(
            id: "verse-1-1",
            chapterNumber: 1,
            verseNumber: 1,
            translations: [
                "vi": DhammapadaVerse.Translation(
                    chapterTitle: "Phẩm Song Yếu",
                    text: "Ý dẫn đầu các pháp,\nÝ làm chủ, ý tạo;\nNếu với ý ô nhiễm,\nNói lên hay hành động,\nKhổ não bước theo sau,\nNhư xe, chân vật kéo.",
                    translator: "HT. Thích Minh Châu",
                    source: "fallback"
                ),
                "en": DhammapadaVerse.Translation(
                    chapterTitle: "Pairs",
                    text: "Mind precedes all mental states. Mind is their chief; they are mind-made. If with an impure mind a person speaks or acts, suffering follows him like the wheel that follows the foot of the ox.",
                    translator: "Gil Fronsdal",
                    source: "fallback"
                )
            ]
        ),
        DhammapadaVerse(
            id: "verse-1-2",
            chapterNumber: 1,
            verseNumber: 2,
            translations: [
                "vi": DhammapadaVerse.Translation(
                    chapterTitle: "Phẩm Song Yếu",
                    text: "Ý dẫn đầu các pháp,\nÝ làm chủ, ý tạo;\nNếu với ý thanh tịnh,\nNói lên hay hành động,\nAn lạc bước theo sau,\nNhư bóng, không rời hình.",
                    translator: "HT. Thích Minh Châu",
                    source: "fallback"
                ),
                "en": DhammapadaVerse.Translation(
                    chapterTitle: "Pairs",
                    text: "Mind precedes all mental states. Mind is their chief; they are mind-made. If with a pure mind a person speaks or acts, happiness follows him like his never-departing shadow.",
                    translator: "Gil Fronsdal",
                    source: "fallback"
                )
            ]
        ),
        DhammapadaVerse(
            id: "verse-1-5",
            chapterNumber: 1,
            verseNumber: 5,
            translations: [
                "vi": DhammapadaVerse.Translation(
                    chapterTitle: "Phẩm Song Yếu",
                    text: "Với hận diệt hận thù,\nĐời này không có được.\nKhông hận diệt hận thù,\nLà định luật ngàn thu.",
                    translator: "HT. Thích Minh Châu",
                    source: "fallback"
                ),
                "en": DhammapadaVerse.Translation(
                    chapterTitle: "Pairs",
                    text: "Hatred is never appeased by hatred in this world. By non-hatred alone is hatred appeased. This is a law eternal.",
                    translator: "Narada Thera",
                    source: "fallback"
                )
            ]
        ),
        DhammapadaVerse(
            id: "verse-2-25",
            chapterNumber: 2,
            verseNumber: 25,
            translations: [
                "vi": DhammapadaVerse.Translation(
                    chapterTitle: "Phẩm Không Phóng Dật",
                    text: "Nỗ lực, không phóng dật,\nTự điều, khéo chế ngự.\nBậc trí xây hòn đảo,\nNước lụt khó ngập tràn.",
                    translator: "HT. Thích Minh Châu",
                    source: "fallback"
                ),
                "en": DhammapadaVerse.Translation(
                    chapterTitle: "Heedfulness",
                    text: "By effort and heedfulness, discipline and self-mastery, let the wise one make for himself an island which no flood can overwhelm.",
                    translator: "Acharya Buddharakkhita",
                    source: "fallback"
                )
            ]
        )
    ]
}

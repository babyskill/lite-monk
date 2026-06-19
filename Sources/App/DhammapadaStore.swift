import Combine
import Foundation
import AgentPetCore

struct DhammapadaVerse: Codable, Equatable, Identifiable {
    var id: String
    var chapterNumber: Int
    var chapterTitle: String
    var verseNumber: Int
    var text: String
    var translator: String
    var source: String

    init(
        id: String = UUID().uuidString,
        chapterNumber: Int,
        chapterTitle: String,
        verseNumber: Int,
        text: String,
        translator: String,
        source: String
    ) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.verseNumber = verseNumber
        self.text = text
        self.translator = translator
        self.source = source
    }

    static var blank: DhammapadaVerse {
        DhammapadaVerse(
            chapterNumber: 1,
            chapterTitle: "Phẩm mới",
            verseNumber: 1,
            text: "",
            translator: "",
            source: ""
        )
    }

    func normalized() -> DhammapadaVerse {
        var normalized = self
        normalized.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.chapterTitle = chapterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.translator = translator.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }

    static func nextID() -> String { UUID().uuidString }

    // Old bundled JSON files have no `id`, so missing IDs are generated on decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decodeIfPresent(String.self, forKey: .id) ?? Self.nextID()
        let chapterNumber = try c.decode(Int.self, forKey: .chapterNumber)
        let chapterTitle = try c.decode(String.self, forKey: .chapterTitle)
        let verseNumber = try c.decode(Int.self, forKey: .verseNumber)
        let text = try c.decode(String.self, forKey: .text)
        let translator = try c.decodeIfPresent(String.self, forKey: .translator) ?? ""
        let source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.init(
            id: id,
            chapterNumber: chapterNumber,
            chapterTitle: chapterTitle,
            verseNumber: verseNumber,
            text: text,
            translator: translator,
            source: source
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case chapterNumber
        case chapterTitle
        case verseNumber
        case text
        case translator
        case source
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
        URL(fileURLWithPath: AgentPetPaths.baseDir)
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
            // Non-critical: keep current in-memory verses so app remains usable.
            print("[AgentPet] Failed saving Dhammapada data: \(error.localizedDescription)")
        }
    }

    private static func loadCustom() -> [DhammapadaVerse]? {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode([DhammapadaVerse].self, from: data))
    }

    private static func loadBundled(from bundle: Bundle) -> [DhammapadaVerse] {
        guard let url = bundle.url(forResource: "Dhammapada.vi", withExtension: "json") else {
            return fallbackVerses
        }

        do {
            let data = try Data(contentsOf: url)
            let verses = try JSONDecoder().decode([DhammapadaVerse].self, from: data)
            return verses.isEmpty ? fallbackVerses : verses
        } catch {
            return fallbackVerses
        }
    }

    // Keeps the pet usable even if the bundled JSON is missing or malformed.
    private static let fallbackVerses: [DhammapadaVerse] = [
        DhammapadaVerse(
            chapterNumber: 1,
            chapterTitle: "Phẩm Song Yếu",
            verseNumber: 1,
            text: """
                Ý dẫn đầu các pháp,
                Ý làm chủ, ý tạo;
                Nếu với ý ô nhiễm,
                Nói lên hay hành động,
                Khổ não bước theo sau,
                Như xe, chân vật kéo.
                """,
            translator: "HT. Thích Minh Châu",
            source: "fallback"
        ),
        DhammapadaVerse(
            chapterNumber: 1,
            chapterTitle: "Phẩm Song Yếu",
            verseNumber: 2,
            text: """
                Ý dẫn đầu các pháp,
                Ý làm chủ, ý tạo;
                Nếu với ý thanh tịnh,
                Nói lên hay hành động,
                An lạc bước theo sau,
                Như bóng, không rời hình.
                """,
            translator: "HT. Thích Minh Châu",
            source: "fallback"
        ),
        DhammapadaVerse(
            chapterNumber: 1,
            chapterTitle: "Phẩm Song Yếu",
            verseNumber: 5,
            text: """
                Với hận diệt hận thù,
                Đời này không có được.
                Không hận diệt hận thù,
                Là định luật ngàn thu.
                """,
            translator: "HT. Thích Minh Châu",
            source: "fallback"
        ),
        DhammapadaVerse(
            chapterNumber: 2,
            chapterTitle: "Phẩm Không Phóng Dật",
            verseNumber: 25,
            text: """
                Nỗ lực, không phóng dật,
                Tự điều, khéo chế ngự.
                Bậc trí xây hòn đảo,
                Nước lụt khó ngập tràn.
                """,
            translator: "HT. Thích Minh Châu",
            source: "fallback"
        ),
    ]
}

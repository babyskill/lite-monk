import Foundation

@MainActor
enum IdleBoost {
    static var dhammapadaVerses: [String] {
        DhammapadaStore.shared.verses.map(\.text)
    }

    // Alias for backwards compatibility with any remaining call sites or tests
    static var dhammapadaVersesVi: [String] {
        dhammapadaVerses
    }

    static func randomDhammapadaLine(excluding current: String? = nil) -> String {
        let verses = dhammapadaVerses
        guard !verses.isEmpty else { return "" }
        guard verses.count > 1, let current else {
            return verses.randomElement() ?? ""
        }

        var candidate = verses.randomElement() ?? ""
        var attempts = 0
        while candidate == current && attempts < 6 {
            candidate = verses.randomElement() ?? ""
            attempts += 1
        }
        return candidate
    }

    static func randomDhammapadaVerse(excluding currentId: String? = nil) -> DhammapadaVerse? {
        let verses = DhammapadaStore.shared.verses
        guard !verses.isEmpty else { return nil }
        guard verses.count > 1, let currentId else {
            return verses.randomElement()
        }

        var candidate = verses.randomElement()
        var attempts = 0
        while candidate?.id == currentId && attempts < 6 {
            candidate = verses.randomElement()
            attempts += 1
        }
        return candidate
    }

    static func dhammapadaLine(at date: Date = Date()) -> String {
        let verses = dhammapadaVerses
        guard !verses.isEmpty else { return "" }
        let slot = max(0, Int(date.timeIntervalSince1970 / (5 * 60)))
        return verses[slot % verses.count]
    }

    static func dhammapadaVerse(at date: Date = Date()) -> DhammapadaVerse? {
        let verses = DhammapadaStore.shared.verses
        guard !verses.isEmpty else { return nil }
        let slot = max(0, Int(date.timeIntervalSince1970 / (5 * 60)))
        return verses[slot % verses.count]
    }
}

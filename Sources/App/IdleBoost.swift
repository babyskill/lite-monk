import Foundation

@MainActor
enum IdleBoost {
    static var dhammapadaVersesVi: [String] {
        DhammapadaStore.shared.verses.map(\.text)
    }

    static func randomDhammapadaLine(excluding current: String? = nil) -> String {
        let verses = dhammapadaVersesVi
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

    static func dhammapadaLine(at date: Date = Date()) -> String {
        let verses = dhammapadaVersesVi
        guard !verses.isEmpty else { return "" }
        let slot = max(0, Int(date.timeIntervalSince1970 / (5 * 60)))
        return verses[slot % verses.count]
    }
}

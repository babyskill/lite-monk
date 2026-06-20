import XCTest
@testable import litemonk

@MainActor
final class IdleBoostTests: XCTestCase {
    func testIdleMessagesLoadFromBundledDataset() {
        XCTAssertGreaterThanOrEqual(IdleBoost.dhammapadaVerses.count, 32)
        XCTAssertTrue(
            IdleBoost.dhammapadaVerses.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
    }

    func testDhammapadaStoreKeepsTranslatorMetadata() {
        // App language defaults to .vi, so first verse should match the Vietnamese translator
        AppLanguage.shared.lang = .vi
        XCTAssertEqual(DhammapadaStore.shared.verses.first?.translator, "HT. Thích Minh Châu")
    }

    func testDhammapadaLinesStayExactVietnameseVerses() {
        AppLanguage.shared.lang = .vi
        XCTAssertEqual(
            IdleBoost.dhammapadaVerses.first,
            """
            Ý dẫn đầu các pháp,
            Ý làm chủ, ý tạo;
            Nếu với ý ô nhiễm,
            Nói lên hay hành động,
            Khổ não bước theo sau,
            Như xe, chân vật kéo.
            """
        )
    }

    func testDhammapadaLineSwitchesToEnglishAndFallback() {
        // Test English translations (loaded from sample for verse 1)
        AppLanguage.shared.lang = .en
        XCTAssertEqual(
            IdleBoost.dhammapadaVerses.first,
            """
            Mind precedes all mental states. Mind is their chief; they are mind-made. If with an impure mind a person speaks or acts, suffering follows him like the wheel that follows the foot of the ox.
            """
        )
        
        // Test fallback (e.g. verse 3 has no English, so it should fallback to Vietnamese since "vi" is available)
        // Let's check verse index 2 (verse 3 in array)
        let verses = DhammapadaStore.shared.verses
        if verses.count > 2 {
            let verse3 = verses[2]
            XCTAssertEqual(verse3.verseNumber, 3)
            // It has no English translation, so text property should fallback to Vietnamese
            XCTAssertEqual(verse3.text, verse3.translations["vi"]?.text)
        }
    }

    func testDhammapadaSelectionIsStableInsideSameFiveMinuteWindow() {
        let now = Date(timeIntervalSince1970: 600)

        XCTAssertEqual(
            IdleBoost.dhammapadaLine(at: now),
            IdleBoost.dhammapadaLine(at: now.addingTimeInterval(299))
        )
    }

    func testDhammapadaSelectionRotatesAcrossFiveMinuteWindows() {
        let first = IdleBoost.dhammapadaLine(at: Date(timeIntervalSince1970: 0))
        let later = IdleBoost.dhammapadaLine(at: Date(timeIntervalSince1970: 300))

        XCTAssertNotEqual(first, later)
    }

    func testRandomDhammapadaLineAvoidsCurrentWhenPossible() {
        let current = IdleBoost.dhammapadaVerses.first ?? ""
        let next = IdleBoost.randomDhammapadaLine(excluding: current)
        if IdleBoost.dhammapadaVerses.count > 1 {
            XCTAssertNotEqual(next, current)
        }
    }
}

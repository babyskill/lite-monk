import XCTest
@testable import agentpet

@MainActor
final class IdleBoostTests: XCTestCase {
    func testIdleMessagesLoadFromBundledDataset() {
        XCTAssertGreaterThanOrEqual(IdleBoost.dhammapadaVersesVi.count, 32)
        XCTAssertTrue(
            IdleBoost.dhammapadaVersesVi.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        )
    }

    func testDhammapadaStoreKeepsTranslatorMetadata() {
        XCTAssertEqual(DhammapadaStore.shared.verses.first?.translator, "HT. Thích Minh Châu")
    }

    func testDhammapadaLinesStayExactVietnameseVerses() {
        XCTAssertEqual(
            IdleBoost.dhammapadaVersesVi.first,
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
        let current = IdleBoost.dhammapadaVersesVi.first ?? ""
        let next = IdleBoost.randomDhammapadaLine(excluding: current)
        if IdleBoost.dhammapadaVersesVi.count > 1 {
            XCTAssertNotEqual(next, current)
        }
    }
}

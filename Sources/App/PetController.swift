import Foundation
import SwiftUI
import AgentPetCore

/// Owns the selected pet and drives the floating Dhammapada quote bubble.
@MainActor
final class PetController: ObservableObject {
    static let shared = PetController()

    @Published private(set) var mood: PetMood = .idle
    @Published private(set) var quoteLine: String = ""
    @Published private(set) var quoteSwapToken: Int = 0

    @Published var selectedPetID: String? {
        didSet { UserDefaults.standard.set(selectedPetID, forKey: Self.petKey) }
    }
    @Published var showQuote: Bool {
        didSet {
            UserDefaults.standard.set(showQuote, forKey: Self.quoteKey)
            refreshQuote()
        }
    }
    @Published var showIdleMessage: Bool {
        didSet {
            UserDefaults.standard.set(showIdleMessage, forKey: Self.idleMsgKey)
            refreshQuote()
        }
    }
    @Published var showTapMessage: Bool {
        didSet {
            UserDefaults.standard.set(showTapMessage, forKey: Self.tapMsgKey)
        }
    }
    @Published var petPoint: Double {
        didSet { UserDefaults.standard.set(petPoint, forKey: Self.sizeKey) }
    }

    static let minPoint: Double = 60
    static let maxPoint: Double = 240
    static let presets: [(String, Double)] = [("S", 84), ("M", 120), ("L", 168)]

    /// Floating window width should always clear the pet and quote bubble.
    static func windowSize(forPoint point: Double, lineCount: Int = 1) -> CGSize {
        let count = max(lineCount, 1)
        let bubbleH = CGFloat(count) * 22 + 16
        return CGSize(
            width: max(point + 110, 320),
            height: point + bubbleH + 28
        )
    }
    var windowSize: CGSize { Self.windowSize(forPoint: petPoint, lineCount: max(quoteLineCount, 1)) }

    /// Number of wrapped lines in the bubble; drives window height.
    @Published private(set) var quoteLineCount: Int = 1

    private static let petKey = "agentpet.selectedPetID"
    private static let quoteKey = "agentpet.showQuote"
    private static let idleMsgKey = "agentpet.showIdleMessage"
    private static let tapMsgKey = "agentpet.showTapMessage"
    private static let sizeKey = "agentpet.petSize"
    private static let dhammapadaInterval: TimeInterval = 5 * 60
    private static let dhammapadaDisplayDuration: TimeInterval = 20

    private var dhammapadaTimer: Timer?
    private var dhammapadaResetTimer: Timer?

    private var sizeAnimTimer: Timer?
    private var sizeAnimStep = 0
    private var sizeAnimStart = 0.0
    private var sizeAnimTarget = 0.0
    private static let sizeAnimSteps = 14

    init() {
        selectedPetID = UserDefaults.standard.string(forKey: Self.petKey)
        showQuote = (UserDefaults.standard.object(forKey: Self.quoteKey) as? Bool) ?? true
        showIdleMessage = (UserDefaults.standard.object(forKey: Self.idleMsgKey) as? Bool) ?? true
        showTapMessage = (UserDefaults.standard.object(forKey: Self.tapMsgKey) as? Bool) ?? true
        let saved = UserDefaults.standard.object(forKey: Self.sizeKey) as? Double ?? 120
        petPoint = min(max(saved, Self.minPoint), Self.maxPoint)
    }

    func start() {
        startDhammapadaTimer()
        refreshQuote()
    }

    /// Kept for existing call-sites from legacy bell settings.
    func refreshPeriodicIdleMessageSchedule() {
        startDhammapadaTimer()
    }

    /// Kept for legacy bell settings compatibility.
    func showPeriodicMindfulnessMessage() {
        showPeriodicDhammapada()
    }

    private func startDhammapadaTimer() {
        dhammapadaTimer?.invalidate()
        dhammapadaResetTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: Self.dhammapadaInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPeriodicDhammapada()
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        dhammapadaTimer = timer
    }

    private func showPeriodicDhammapada() {
        guard mood == .idle, showQuote, showIdleMessage else { return }
        applySimpleQuoteLine(IdleBoost.dhammapadaLine())

        dhammapadaResetTimer?.invalidate()
        dhammapadaResetTimer = Timer.scheduledTimer(
            withTimeInterval: Self.dhammapadaDisplayDuration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.mood == .idle else { return }
                self.refreshQuote(reroll: true)
            }
        }
        dhammapadaResetTimer?.tolerance = 2
    }

    private func settleAfterCelebrate() {
        mood = .idle
        refreshQuote(reroll: true)
    }

    func flashCelebrate(line: String) {
        mood = .celebrate
        applySimpleQuoteLine(line)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            settleAfterCelebrate()
        }
    }

    /// Re-pick the quote line so it adopts a newly chosen app language at once.
    func relocalize() { refreshQuote(reroll: true) }

    private func refreshQuote(reroll: Bool = true) {
        guard showQuote else {
            applySimpleQuoteLine("")
            return
        }

        if mood == .idle {
            guard showIdleMessage else {
                applySimpleQuoteLine("")
                return
            }
            if reroll || quoteLine.isEmpty {
                applySimpleQuoteLine(IdleBoost.dhammapadaLine())
            }
            StatusBarController.shared.refreshTitle()
            return
        }

        if reroll || quoteLine.isEmpty {
            applySimpleQuoteLine(IdleBoost.dhammapadaLine())
        }
        StatusBarController.shared.refreshTitle()
    }

    private func applySimpleQuoteLine(_ line: String) {
        if mood == .idle, line != quoteLine {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                quoteSwapToken &+= 1
            }
        }
        quoteLine = line
        quoteLineCount = lineCount(for: line)
        StatusBarController.shared.refreshTitle()
    }

    private func lineCount(for line: String) -> Int {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 1 }
        return max(1, line.components(separatedBy: .newlines).count)
    }

    // MARK: - Pet interaction

    @Published private(set) var isPetted = false
    @Published private(set) var petReactionLine: String = ""
    @Published private(set) var petTapCount: Int = 0

    private var petBounceTimer: Timer?
    private var petLineTimer: Timer?
    private var consecutivePets = 0
    private var lastPetTime: Date?

    private static let petReactions: [[String]] = [
        ["A-di-đà Phật, con chạm nhẹ thôi nha~", "Ơ kìa, ai vuốt con đó?", "Con cúi đầu chào thí chủ 👋", "Nghịch tí thôi mà~", "*tung tăng*"],
        ["Con xin phép nghịch thêm chút nữa!", "Thầy ơi, con thích được vuốt quá!", "Hihi, con đang vui lắm~", "Mô Phật, con nhảy đây ✨"],
        ["A-di-đà Phật, con hết chịu nổi rồi! 💖", "Con xin thành thật: con đang rất quậy! 😆", "Vuốt nữa đi, con ngoan mà~"]
    ]

    func petTap() {
        let now = Date()
        if let last = lastPetTime, now.timeIntervalSince(last) < 3.0 {
            consecutivePets += 1
        } else {
            consecutivePets = 1
        }
        lastPetTime = now

        if showTapMessage {
            let tier = consecutivePets >= 6 ? 2 : consecutivePets >= 3 ? 1 : 0
            petReactionLine = Self.petReactions[tier].randomElement() ?? "A-di-đà Phật, con chạm nhẹ thôi nha~"
        } else {
            petReactionLine = ""
        }
        petTapCount += 1

        if showQuote && showIdleMessage && mood == .idle {
            applySimpleQuoteLine(IdleBoost.randomDhammapadaLine(excluding: quoteLine))
        }

        isPetted = true
        petBounceTimer?.invalidate()
        petBounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
            Task { @MainActor [weak self] in self?.isPetted = false }
        }

        petLineTimer?.invalidate()
        petLineTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor [weak self] in self?.petReactionLine = "" }
        }

        BundledSound.bonk.play(repeatCount: 3, fallbackNamed: "Pop")
    }

    // MARK: - Pet size

    /// Eases `petPoint` to a target so a preset tap resizes as smoothly as a
    /// slider drag (each step drives the same smooth window resize).
    func animateSize(to target: Double) {
        sizeAnimTimer?.invalidate()
        sizeAnimTarget = min(max(target, Self.minPoint), Self.maxPoint)
        sizeAnimStart = petPoint
        sizeAnimStep = 0
        sizeAnimTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.tickSize() }
        }
    }

    private func tickSize() {
        sizeAnimStep += 1
        let t = min(Double(sizeAnimStep) / Double(Self.sizeAnimSteps), 1)
        let eased = t * t * (3 - 2 * t)
        petPoint = sizeAnimStart + (sizeAnimTarget - sizeAnimStart) * eased
        if sizeAnimStep >= Self.sizeAnimSteps {
            petPoint = sizeAnimTarget
            sizeAnimTimer?.invalidate()
        }
    }
}

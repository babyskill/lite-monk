import Foundation
import AgentPetCore

/// The chosen pet: a built-in vector pet or an imported spritesheet pack.
enum PetSelection: Equatable {
    case builtin(PetKind)
    case imported(String)   // image pack id

    var storageString: String {
        switch self {
        case .builtin(let kind): return "builtin:\(kind.rawValue)"
        case .imported(let id): return "imported:\(id)"
        }
    }

    init?(storageString: String) {
        let parts = storageString.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "builtin":
            guard let kind = PetKind(rawValue: parts[1]) else { return nil }
            self = .builtin(kind)
        case "imported":
            self = .imported(parts[1])
        default:
            return nil
        }
    }
}

/// Resolves the aggregate session mood for the pet and plays a short
/// `celebrate` burst when work just finished. Also owns the selected pet.
@MainActor
final class PetController: ObservableObject {
    static let shared = PetController()

    @Published private(set) var mood: PetMood = .idle
    @Published var selection: PetSelection {
        didSet { UserDefaults.standard.set(selection.storageString, forKey: Self.selectionKey) }
    }

    private var lastResolved: PetMood = .idle
    private var latestSessions: [AgentSession] = []
    private var celebrateTimer: Timer?

    private static let selectionKey = "agentpet.petSelection"
    private static let celebrateDuration: TimeInterval = 3

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.selectionKey)
        selection = saved.flatMap(PetSelection.init(storageString:)) ?? .builtin(.blob)
    }

    func start() {}

    /// Called by the daemon whenever the session list changes.
    func update(sessions: [AgentSession]) {
        latestSessions = sessions
        let resolved = MoodResolver.aggregate(sessions)
        defer { lastResolved = resolved }

        if resolved == .done && lastResolved != .done {
            mood = .celebrate
            celebrateTimer?.invalidate()
            celebrateTimer = Timer.scheduledTimer(withTimeInterval: Self.celebrateDuration, repeats: false) { _ in
                Task { @MainActor [weak self] in self?.settleAfterCelebrate() }
            }
            return
        }
        if mood == .celebrate && resolved == .done {
            return  // let the celebration finish
        }
        celebrateTimer?.invalidate()
        mood = resolved
    }

    private func settleAfterCelebrate() {
        mood = MoodResolver.aggregate(latestSessions)
    }
}

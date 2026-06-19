import Foundation

/// The animation states a pet pack can provide.
public enum PetMood: String, Codable, Sendable, CaseIterable {
    case idle
    case working
    case waiting
    case done
    case celebrate
}

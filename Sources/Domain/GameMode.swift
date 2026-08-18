import Foundation

/// Local-only setting (never sent to the server) that drives ship-placement's
/// opponent picker. Order matches the Android spinner order.
enum GameMode: Int, CaseIterable, Identifiable {
    case computerEasy
    case computerMedium
    case computerHard
    case playerRandom
    case playerSelected

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .computerEasy: return "Computer - Easy"
        case .computerMedium: return "Computer - Medium"
        case .computerHard: return "Computer - Hard"
        case .playerRandom: return "Random Player"
        case .playerSelected: return "Selected Player"
        }
    }

    var isComputer: Bool {
        switch self {
        case .computerEasy, .computerMedium, .computerHard: return true
        case .playerRandom, .playerSelected: return false
        }
    }

    /// Offline devices may only start a game against the computer.
    static let offlineModes: [GameMode] = [.computerEasy, .computerMedium, .computerHard]
}

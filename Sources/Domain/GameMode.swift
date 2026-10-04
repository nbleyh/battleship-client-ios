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
        case .computerEasy: return String(localized: "mode_computer_easy")
        case .computerMedium: return String(localized: "mode_computer_medium")
        case .computerHard: return String(localized: "mode_computer_hard")
        case .playerRandom: return String(localized: "mode_random_player")
        case .playerSelected: return String(localized: "mode_selected_player")
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

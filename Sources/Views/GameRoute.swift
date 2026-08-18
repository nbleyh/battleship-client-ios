import Foundation

/// Navigation destinations pushed onto the Games tab's `NavigationPath`.
/// Keeping the path (rather than nested per-screen `navigationDestination`s)
/// lets the "Overview" button pop all the way back to the games list in one
/// step, regardless of how deep the current screen is.
enum GameRoute: Hashable {
    case prepare(existingGame: Game?)
    case computerGame(Game, Computer)
    case remoteGame(Game)
}

/// Reference identity is sufficient here — a `Computer` is only ever used to
/// drive its own local AI opponent for the lifetime of one game screen.
extension Computer: Hashable {
    static func == (lhs: Computer, rhs: Computer) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

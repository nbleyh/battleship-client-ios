import Foundation

enum APIError: Error {
    case invalidResponse
    case http(status: Int)
    case decoding(Error)
    case encoding(Error)

    /// Server returns 401 specifically when registering a player name that's
    /// already taken (see `BattleshipServer.register` on the server).
    var isPlayerAlreadyExists: Bool {
        if case .http(let status) = self { return status == 401 }
        return false
    }
}

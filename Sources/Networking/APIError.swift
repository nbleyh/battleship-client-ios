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

    /// Server returns 404 specifically when the requested player genuinely
    /// no longer exists (see `PlayerController.getPlayer` on the server) —
    /// as opposed to a transient network/connectivity failure, which throws
    /// something else entirely (a `URLError`, not `.http`) and must NOT be
    /// treated the same way by callers that react to this by discarding a
    /// locally saved identity.
    var isNotFound: Bool {
        if case .http(let status) = self { return status == 404 }
        return false
    }
}

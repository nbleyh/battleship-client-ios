import Foundation

/// URLSession-based port of the Android `RetrofitClient` / `BattleshipServer`
/// interface. Talks to the same live REST backend, so the JSON wire format
/// (field names, date format) must match the Java `Gson` config exactly.
actor BattleshipAPI {
    static let shared = BattleshipAPI()

    private let baseURL = "https://www.echoshapes.com/battleship/rest/"
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = BattleshipAPI.makeSession()) {
        self.session = session

        let formatter = DateFormatter()
        formatter.dateFormat = Constants.dateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .formatted(formatter)
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .formatted(formatter)
        self.decoder = dec
    }

    func register(_ player: Player) async throws -> Player {
        try await perform("player", method: "POST", body: player)
    }

    func updatePlayer(_ player: Player) async throws -> Player {
        try await perform("player", method: "PUT", body: player)
    }

    func getPlayer(named name: String) async throws -> Player {
        try await perform("player/\(encodedPathComponent(name))", method: "GET")
    }

    func getPlayers() async throws -> [Player] {
        try await perform("player/list", method: "GET")
    }

    func getGames(for playerName: String) async throws -> [Game] {
        try await perform("game/list/\(encodedPathComponent(playerName))", method: "GET")
    }

    func getGame(_ id: Int) async throws -> Game {
        try await perform("game/\(id)", method: "GET")
    }

    func startGame(_ game: Game) async throws -> Game {
        try await perform("game/", method: "POST", body: game)
    }

    func processTurn(_ game: Game) async throws -> Game {
        try await perform("game", method: "PUT", body: game)
    }

    private func encodedPathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    /// Defense in depth, not the fix for the Games-list staleness bug (that
    /// turned out to be `Game`'s `Equatable`/`Hashable` — see `Game.swift`).
    /// `URLSession.shared` carries `URLSessionConfiguration.default`'s
    /// `URLCache`; a dedicated session with `urlCache = nil` removes it
    /// outright rather than relying solely on each request's
    /// `.reloadIgnoringLocalCacheData`, in case a future response ever grows
    /// real cache-control headers server-side.
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    private func perform<Response: Decodable>(_ path: String, method: String, body: Encodable? = nil) async throws -> Response {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Belt-and-suspenders on top of `makeSession()`'s cache-less
        // `URLSessionConfiguration`: an explicit request-level bypass, plus
        // a `Cache-Control` header in case anything between here and the
        // server (a proxy, a CDN) is caching GETs despite the server itself
        // sending no cache-control/validator headers of its own.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encoding(error)
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

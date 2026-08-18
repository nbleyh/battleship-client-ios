import Foundation

/// Port of the Android Game domain object. A value type (rather than the Java
/// mutable class) so it composes cleanly with a `@Published` property in an
/// `ObservableObject` view model — every `mutating func` below still maps
/// 1:1 to a method of the same name on the Java class.
struct Game: Codable, Identifiable, Hashable {
    var gameId: Int = 0
    var player1: Player?
    var player2: Player?
    var lastUpdate: Date?
    var status: GameStatus = .waiting
    var shipsPlayer1: Set<Ship> = []
    var shipsPlayer2: Set<Ship> = []
    var turnsPlayer1: [Turn] = []
    var turnsPlayer2: [Turn] = []

    /// Computed locally after fetch/creation via `calculateFieldValues()`; never
    /// sent to or received from the server (mirrors the Java `transient` fields).
    private var fieldValuesPlayer1: [[Int]]?
    private var fieldValuesPlayer2: [[Int]]?

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case player1 = "player_1"
        case player2 = "player_2"
        case lastUpdate = "last_update"
        case status
        case shipsPlayer1, shipsPlayer2, turnsPlayer1, turnsPlayer2
    }

    var id: Int { gameId }

    init() {}

    init(player1: Player) {
        self.player1 = player1
    }

    /// Deliberately full structural equality (everything but the private,
    /// locally-recomputed field-value caches) — NOT just `gameId`. This type
    /// backs `GamesListView`'s `ForEach(appState.games)`, and SwiftUI's List
    /// diffing uses `Equatable` to decide whether a row with unchanged
    /// identity still needs to re-render. An id-only `==` (this used to be
    /// `lhs.gameId == rhs.gameId`, mirroring the Java `equals()` that ordered
    /// the old `TreeSet<Game>`) makes a `WAITING`-vs-`WIN_PLAYER1` status
    /// flip on an already-known game compare as "no change" and get dropped
    /// silently — the Games list would poll successfully forever and never
    /// show the finished game. `gameId` still dominates `hash(into:)` since
    /// it's the actual stable identity; the rest of the fields only need to
    /// affect equality.
    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.gameId == rhs.gameId
            && lhs.player1 == rhs.player1
            && lhs.player2 == rhs.player2
            && lhs.lastUpdate == rhs.lastUpdate
            && lhs.status == rhs.status
            && lhs.shipsPlayer1 == rhs.shipsPlayer1
            && lhs.shipsPlayer2 == rhs.shipsPlayer2
            && lhs.turnsPlayer1 == rhs.turnsPlayer1
            && lhs.turnsPlayer2 == rhs.turnsPlayer2
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(gameId)
        hasher.combine(status)
        hasher.combine(lastUpdate)
    }

    var description: String {
        if let player2 {
            return "\(player1?.name ?? "") against \(player2.name)"
        }
        return "\(player1?.name ?? "") against ..."
    }

    func opponent(of player: Player) -> Player? {
        player1?.name == player.name ? player2 : player1
    }

    func ships(for player: Player) -> Set<Ship> {
        player1?.name == player.name ? shipsPlayer1 : shipsPlayer2
    }

    func turns(for player: Player) -> [Turn] {
        player1?.name == player.name ? turnsPlayer1 : turnsPlayer2
    }

    mutating func addShip(_ ship: Ship, for player: Player) {
        var s = ship
        s.gameId = gameId
        s.playerName = player.name
        if player1?.name == player.name {
            shipsPlayer1.insert(s)
        } else {
            shipsPlayer2.insert(s)
        }
    }

    mutating func removeShip(_ ship: Ship, for player: Player) {
        if player1?.name == player.name {
            shipsPlayer1.remove(ship)
        } else {
            shipsPlayer2.remove(ship)
        }
    }

    mutating func addTurn(_ turn: Turn, for player: Player) {
        var t = turn
        t.gameId = gameId
        t.playerName = player.name
        if player1?.name == player.name {
            turnsPlayer1.append(t)
            turnsPlayer1.sort()
        } else {
            turnsPlayer2.append(t)
            turnsPlayer2.sort()
        }
    }

    mutating func calculateFieldValues() {
        fieldValuesPlayer1 = FieldCalculator.calculateFieldValues(shipsPlayer1)
        fieldValuesPlayer2 = FieldCalculator.calculateFieldValues(shipsPlayer2)
    }

    /// Records `player`'s shot and returns the field value it hit (9 = ship hit,
    /// 0-3 = near-miss hint count).
    @discardableResult
    mutating func fire(_ turn: Turn, by player: Player) -> Int {
        var t = turn
        t.gameId = gameId
        t.playerName = player.name
        t.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        if player1?.name == player.name {
            turnsPlayer1.append(t)
            turnsPlayer1.sort()
            return fieldValuesPlayer2?[t.x][t.y] ?? 0
        } else {
            turnsPlayer2.append(t)
            turnsPlayer2.sort()
            return fieldValuesPlayer1?[t.x][t.y] ?? 0
        }
    }

    func isHit(_ turn: Turn, by player: Player) -> Int {
        player1?.name == player.name
            ? (fieldValuesPlayer2?[turn.x][turn.y] ?? 0)
            : (fieldValuesPlayer1?[turn.x][turn.y] ?? 0)
    }

    func hits(for player: Player) -> Int {
        let isP1 = player1?.name == player.name
        let turns = isP1 ? turnsPlayer1 : turnsPlayer2
        guard let field = isP1 ? fieldValuesPlayer2 : fieldValuesPlayer1 else { return 0 }
        return turns.filter { field[$0.x][$0.y] == 9 }.count
    }

    func isPlayerTurn(_ player: Player) -> Bool {
        switch status {
        case .turnPlayer1: return player1?.name == player.name
        case .turnPlayer2: return player2?.name == player.name
        default: return false
        }
    }

    func isPlayerWinner(_ player: Player) -> Bool {
        switch status {
        case .winPlayer1: return player1?.name == player.name
        case .winPlayer2: return player2?.name == player.name
        default: return false
        }
    }

    var isFinished: Bool {
        status == .winPlayer1 || status == .winPlayer2
    }

    mutating func setWinner(_ player: Player) {
        status = (player1?.name == player.name) ? .winPlayer1 : .winPlayer2
    }

    mutating func setTurnStatus(_ player: Player) {
        status = (player1?.name == player.name) ? .turnPlayer1 : .turnPlayer2
    }
}

extension Game {
    /// Sorts most-recently-updated first, matching the Java `compareTo`
    /// (which the Java `TreeSet<Game>` used to order `Player.myGames`).
    static func sortedByRecency(_ games: [Game]) -> [Game] {
        games.sorted { ($0.lastUpdate ?? .distantPast) > ($1.lastUpdate ?? .distantPast) }
    }
}

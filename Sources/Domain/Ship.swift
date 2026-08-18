import Foundation

struct Ship: Codable, Hashable {
    var shipId: Int = 0
    var x: Int
    var y: Int
    var playerName: String? = nil
    var gameId: Int = 0
    var hit: Bool = false

    enum CodingKeys: String, CodingKey {
        case shipId = "ship_id"
        case x, y, playerName
        case gameId = "game_id"
        case hit
    }

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Parses a cell tag such as "myField23" or "field45" into (x, y) — the
    /// last two characters are the row and column digits, mirroring the Java
    /// `Ship(String name)` constructor.
    init(tag: String) {
        let chars = Array(tag)
        self.x = Int(String(chars[chars.count - 2]))!
        self.y = Int(String(chars[chars.count - 1]))!
    }

    static func == (lhs: Ship, rhs: Ship) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

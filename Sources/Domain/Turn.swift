import Foundation

struct Turn: Codable, Comparable {
    var turnId: Int = 0
    var x: Int
    var y: Int
    var playerName: String? = nil
    var gameId: Int = 0
    var timestamp: Int64 = 0

    enum CodingKeys: String, CodingKey {
        case turnId = "turn_id"
        case x, y, playerName
        case gameId = "game_id"
        case timestamp
    }

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Parses a cell tag such as "myField23" or "field45" into (x, y).
    init(tag: String) {
        let chars = Array(tag)
        self.x = Int(String(chars[chars.count - 2]))!
        self.y = Int(String(chars[chars.count - 1]))!
    }

    static func < (lhs: Turn, rhs: Turn) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}

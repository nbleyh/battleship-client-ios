import Foundation

struct Player: Codable, Hashable, Identifiable {
    var name: String
    var played: Int = 0
    var won: Int = 0
    var rank: Int = 0
    var firebaseToken: String? = nil

    enum CodingKeys: String, CodingKey {
        case name, played, won, rank
        case firebaseToken = "firebase_token"
    }

    var id: String { name }

    init(name: String, firebaseToken: String? = nil) {
        self.name = name
        self.firebaseToken = firebaseToken
    }

    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

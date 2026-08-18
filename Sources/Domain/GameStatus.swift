import Foundation

enum GameStatus: String, Codable {
    case waiting = "WAITING"
    case turnPlayer1 = "TURN_PLAYER1"
    case turnPlayer2 = "TURN_PLAYER2"
    case winPlayer1 = "WIN_PLAYER1"
    case winPlayer2 = "WIN_PLAYER2"
}

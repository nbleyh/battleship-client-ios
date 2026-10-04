import Foundation

/// Ship-placement + opponent-selection screen, ported from `PrepareActivity`.
@MainActor
final class PrepareViewModel: ObservableObject {
    @Published var shipCells: Set<Ship> = []
    @Published var gameMode: GameMode = .playerRandom
    @Published var opponentName: String?
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    let me: Player
    private(set) var game: Game
    /// True when placing ships for a game someone else already created and
    /// invited us into (mirrors Android's `this.game != null` / `!initialGame`).
    let isInvitedGame: Bool
    private let onlineModesAvailable: Bool

    private let api = BattleshipAPI.shared

    init(me: Player, existingGame: Game?, isOnline: Bool) {
        self.me = me
        self.onlineModesAvailable = isOnline
        if var existingGame {
            existingGame.player2 = me
            self.game = existingGame
            self.isInvitedGame = true
            self.gameMode = .playerSelected
            self.opponentName = existingGame.player1?.name
        } else {
            self.game = Game(player1: me)
            self.isInvitedGame = false
        }
    }

    var isModePickerEnabled: Bool { !isInvitedGame }

    var availableModes: [GameMode] {
        (isInvitedGame || onlineModesAvailable) ? GameMode.allCases : GameMode.offlineModes
    }

    var headerText: String {
        String(format: NSLocalizedString("set_your_ships_header", comment: ""), shipCells.count)
    }

    var canStart: Bool { shipCells.count == Constants.numShips }

    func toggle(x: Int, y: Int) {
        let ship = Ship(x: x, y: y)
        if shipCells.contains(ship) {
            shipCells.remove(ship)
        } else if shipCells.count < Constants.numShips {
            shipCells.insert(ship)
        }
    }

    func selectOpponent(_ player: Player) {
        game.player2 = player
        game.status = .turnPlayer2
        opponentName = player.name
    }

    enum StartResult {
        case localGame(Game, Computer)
        case remoteGame(Game)
        case returnedToList
        case failed
    }

    func start(appState: AppState) async -> StartResult {
        for ship in shipCells {
            game.addShip(ship, for: me)
        }

        if gameMode.isComputer {
            let computer = Computer(level: gameMode)
            game.player2 = computer.player
            for ship in computer.shipSet {
                game.addShip(ship, for: computer.player)
            }
            // Local computer games never round-trip through the server, so
            // nothing else sets an initial turn status. Without this, `status`
            // stays `.waiting`, `isPlayerTurn(me)` is false, and the game
            // screen sits on "opponent's turn" forever with no timer and no
            // driver to move the computer — i.e. it freezes.
            game.setTurnStatus(me)
            return .localGame(game, computer)
        }

        if game.isPlayerTurn(me) {
            return .remoteGame(game)
        }

        isSubmitting = true
        do {
            let saved = isInvitedGame ? try await api.processTurn(game) : try await api.startGame(game)
            isSubmitting = false
            appState.upsert(saved)
            return .returnedToList
        } catch {
            isSubmitting = false
            errorMessage = String(localized: "app_error")
            return .failed
        }
    }
}

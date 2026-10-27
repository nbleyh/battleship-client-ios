import Foundation
import UIKit

/// Drives a single game screen. Combines what Android split across
/// `MasterGameActivity` (shared board/timer logic), `PlayerGameActivity`
/// (remote opponent via REST + push), `ComputerGameActivity` (local AI
/// opponent), and `OpponentThread` (the AI's delayed move) into one view
/// model parameterized by an opponent driver.
@MainActor
final class GameViewModel: ObservableObject {
    enum Driver {
        case computer(Computer)
        case remote
    }

    @Published private(set) var game: Game
    @Published var me: Player
    @Published var actionText = String(localized: "your_turn")
    @Published var actionIsRed = false
    @Published var showOverviewButton = false
    @Published var isTargetGridEnabled = false
    @Published var isTimerVisible = false
    /// 1.0 at turn start, ticking down to 0.0 over the 15s turn limit.
    @Published var timerFraction: Double = 1.0
    /// nil until the initial fetch resolves — the icon stays hidden rather
    /// than momentarily showing greyed-out-for-0 before the real balance loads.
    @Published private(set) var coins: Int?
    /// Toggled by tapping the (enabled) double-shot icon — see `toggleDoubleShot()`.
    /// While selected: the icon gets a bold border, the turn timer restarts at 30s
    /// (instead of 15s) so there's time for 2 shots, and `tapTargetCell` lets the
    /// first of those 2 shots fall through without ending the turn. The 2 coins are
    /// actually spent only once the turn that used it ends (see
    /// `spendDoubleShotIfSelected()`) — not here, so toggling it back off before
    /// firing costs nothing.
    @Published var isDoubleShotSelected = false
    private var shotsFiredThisTurn = 0

    /// Double-shot only makes sense against a real opponent — a computer
    /// game never round-trips through the server to spend it against.
    var isRemoteGame: Bool { if case .remote = driver { true } else { false } }
    /// Bottom-left icon: visible for the whole time it's actually my turn,
    /// in a remote game.
    var showDoubleShotIcon: Bool { isRemoteGame && isTargetGridEnabled }
    var canDoubleShot: Bool { (coins ?? 0) >= 2 }

    let opponent: Player?

    private let driver: Driver
    private let api = BattleshipAPI.shared
    private var timerTask: Task<Void, Never>?
    private var updatesTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    /// Wired up post-init via `configure(appState:)`, since `@EnvironmentObject`
    /// isn't available inside a View's `init`.
    private var onGameFinished: (Player) -> Void = { _ in }
    private var onGamePersisted: (Game) -> Void = { _ in }

    init(game: Game, me: Player, driver: Driver) {
        var g = game
        g.calculateFieldValues()
        self.game = g
        self.me = me
        self.opponent = g.opponent(of: me)
        self.driver = driver
    }

    /// Reflects a finished game's updated play/win count and any freshly
    /// persisted game state back into the shared app-level state.
    func configure(appState: AppState) {
        onGameFinished = { [weak appState] updatedMe in
            appState?.player = updatedMe
        }
        onGamePersisted = { [weak appState] game in
            appState?.upsert(game)
        }
    }

    func start() {
        if game.isFinished {
            actionText = game.isPlayerWinner(me) ? String(localized: "you_won") : String(localized: "you_lost")
            showOverviewButton = true
            isTargetGridEnabled = false
        } else if game.isPlayerTurn(me) {
            isTargetGridEnabled = true
            beginTurnTimer()
        } else {
            actionText = String(format: NSLocalizedString("opponent_turn_in_progress", comment: ""), opponentName)
            actionIsRed = true
            isTargetGridEnabled = false
        }

        if case .remote = driver {
            subscribeToUpdates()
            beginPolling()
        }
        // Header shown for every game, not just remote ones — matches
        // MainTabView's "name: N Coins" bar (TabedActivity on Android).
        loadCoins()
    }

    /// Refreshed whenever the turn flips back to me (see `refresh(with:)`)
    /// too, not just once at `start()` — the balance can change between
    /// turns once something actually spends it.
    private func loadCoins() {
        Task { [weak self] in
            guard let self else { return }
            self.coins = try? await self.api.getCoins(for: self.me.name)
        }
    }

    func stop() {
        timerTask?.cancel()
        updatesTask?.cancel()
        pollTask?.cancel()
    }

    private var opponentName: String { opponent?.name ?? String(localized: "opponent_fallback_name") }

    // MARK: - Board rendering

    /// Image for one of "my" cells (my ships, hit by the opponent).
    func myGridImage(x: Int, y: Int) -> String {
        guard let opponent else {
            return game.ships(for: me).contains(Ship(x: x, y: y)) ? "Ship" : "Fog"
        }
        let opponentTurns = game.turns(for: opponent)
        guard let matching = opponentTurns.last(where: { $0.x == x && $0.y == y }) else {
            return game.ships(for: me).contains(Ship(x: x, y: y)) ? "Ship" : "Fog"
        }
        let value = game.isHit(matching, by: opponent)
        let isLast = opponentTurns.last?.x == x && opponentTurns.last?.y == y
        return Self.imageName(for: value, stroked: isLast)
    }

    /// Image for one of the opponent-facing target cells (my shots).
    func targetGridImage(x: Int, y: Int) -> String {
        let myTurns = game.turns(for: me)
        guard let matching = myTurns.last(where: { $0.x == x && $0.y == y }) else {
            return "Fog"
        }
        let value = game.isHit(matching, by: me)
        let isLast = myTurns.last?.x == x && myTurns.last?.y == y
        return Self.imageName(for: value, stroked: isLast)
    }

    private static func imageName(for value: Int, stroked: Bool) -> String {
        if value == 9 { return stroked ? "ShipHitStroke" : "ShipHit" }
        return stroked ? "Waterdrop\(value)Stroke" : "Waterdrop\(value)"
    }

    // MARK: - Player actions

    func tapTargetCell(x: Int, y: Int) {
        guard isTargetGridEnabled else { return }
        guard !game.turns(for: me).contains(where: { $0.x == x && $0.y == y }) else { return }

        let turn = Turn(x: x, y: y)
        let value = game.fire(turn, by: me)
        if value == 9 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        if game.hits(for: me) == Constants.numShips {
            game.setWinner(me)
            finishGame(winner: me)
        } else if shouldEndTurnAfterShot() {
            endMyTurn()
        }
        // else: double-shot's first of 2 shots — this shot's visual update
        // above already happened; leave the grid (and timer) running for
        // the second one instead of ending the turn.
    }

    /// Whether firing at the cell just hit/missed should end the turn.
    /// Always true for one shot per turn — false after the first of 2 when
    /// double-shot is selected, so the turn continues for a second tap.
    private func shouldEndTurnAfterShot() -> Bool {
        shotsFiredThisTurn += 1
        return !isDoubleShotSelected || shotsFiredThisTurn >= 2
    }

    /// Toggled by tapping the double-shot icon. Turning it ON requires
    /// `canDoubleShot` and that no shot has been fired yet this turn; turning
    /// it back OFF is always allowed under the same "no shot fired yet" guard.
    /// The running turn timer is left untouched — toggling the icon doesn't
    /// reset or extend it.
    func toggleDoubleShot() {
        guard isTargetGridEnabled, shotsFiredThisTurn == 0 else { return }
        guard isDoubleShotSelected || canDoubleShot else { return }
        isDoubleShotSelected.toggle()
    }

    /// Spends the 2 coins if this turn used double-shot, then resets the
    /// selection for the next turn. Mirrors Android's
    /// `spendDoubleShotIfSelected()`, called from the same two places.
    private func spendDoubleShotIfSelected() {
        if isDoubleShotSelected {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.api.updateCoins(for: self.me.name, delta: -2)
            }
        }
        isDoubleShotSelected = false
        shotsFiredThisTurn = 0
    }

    /// Ends the local player's turn — either because they fired, or because
    /// the turn timer ran out (Android auto-ends the turn either way).
    private func endMyTurn() {
        cancelTurnTimer()
        spendDoubleShotIfSelected()
        showOverviewButton = true
        isTargetGridEnabled = false
        actionText = String(format: NSLocalizedString("opponent_turn_in_progress", comment: ""), opponentName)
        actionIsRed = true

        switch driver {
        case .computer(let computer):
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await runComputerTurn(computer)
            }
        case .remote:
            if let opponent {
                game.setTurnStatus(opponent)
            }
            // Reflect the turn change in the Games list right away — waiting
            // for the PUT below to round-trip (or silently failing it) is
            // what left the list stuck showing "Your turn!" after firing.
            onGamePersisted(game)
            Task {
                if let updated = try? await api.processTurn(game) {
                    var g = updated
                    g.calculateFieldValues()
                    game = g
                    onGamePersisted(game)
                }
            }
        }
    }

    private func runComputerTurn(_ computer: Computer) async {
        let turn = computer.nextTurn()
        let value = game.fire(turn, by: computer.player)
        computer.update(x: turn.x, y: turn.y, value: value)
        if value == 9 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        if game.hits(for: computer.player) == Constants.numShips {
            game.setWinner(computer.player)
            finishGame(winner: computer.player)
        } else {
            isTargetGridEnabled = true
            actionText = String(localized: "your_turn")
            actionIsRed = false
            beginTurnTimer()
        }
    }

    private func finishGame(winner: Player) {
        showOverviewButton = true
        isTargetGridEnabled = false
        cancelTurnTimer()
        spendDoubleShotIfSelected()
        if winner.name == me.name {
            actionText = String(localized: "congratulations_won")
            me.played += 1
            me.won += 1
        } else {
            actionText = String(localized: "you_lost")
            me.played += 1
        }
        onGameFinished(me)
        if case .remote = driver {
            // Same as endMyTurn: update the Games list immediately rather than
            // only after the PUT below completes (or fails silently).
            onGamePersisted(game)
            Task {
                if let updated = try? await api.processTurn(game) {
                    onGamePersisted(updated)
                }
            }
        }
    }

    // MARK: - Turn timer (15s per turn, matching GameCountDownTimer)

    private func beginTurnTimer() {
        isTimerVisible = true
        timerFraction = 1.0
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            let totalSteps = 600 // 15000ms / 25ms, matching the Android tick frequency
            for step in 1...totalSteps {
                try? await Task.sleep(nanoseconds: 25_000_000)
                if Task.isCancelled { return }
                self?.timerFraction = 1.0 - Double(step) / Double(totalSteps)
            }
            if !Task.isCancelled {
                self?.endMyTurn()
            }
        }
    }

    private func cancelTurnTimer() {
        timerTask?.cancel()
        timerTask = nil
        isTimerVisible = false
        timerFraction = 1.0
    }

    // MARK: - Remote updates (replaces UpdatedGameReceiver + push handling)

    private func subscribeToUpdates() {
        updatesTask = Task { [weak self] in
            for await updated in GameUpdateCenter.updates {
                guard let self, updated.gameId == self.game.gameId else { continue }
                self.refresh(with: updated)
            }
        }
    }

    /// Push is the fast path, but it depends on Firebase being configured and
    /// on APNs/FCM actually delivering to this device — neither is guaranteed.
    /// Without a fallback, an open game screen can be stuck forever showing
    /// "opponent's turn" even after the opponent has moved server-side. This
    /// re-fetches periodically so the screen catches up regardless of push.
    private func beginPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                guard let self else { return }
                if let updated = try? await self.api.getGame(self.game.gameId) {
                    // Only feed a genuinely-changed game into refresh(): it
                    // unconditionally re-applies the opponent's last turn
                    // (including a hit vibration), so calling it on every
                    // unchanged poll tick would re-vibrate/re-render
                    // needlessly — mirrors Android's PlayerGameActivity.pollCallback.
                    if let opponent,
                       updated.status != self.game.status
                        || updated.turns(for: opponent).count != self.game.turns(for: opponent).count {
                        self.refresh(with: updated)
                    }
                }
            }
        }
    }

    private func refresh(with updated: Game) {
        guard !game.isFinished else { return }
        // Now that this can be driven by polling and not just a "your turn"
        // push, an update may report no actual change (still the opponent's
        // turn) — only react to a turn change, or repeated polls would keep
        // stomping "Your turn!" and restarting the timer over the opponent's turn.
        let wasMyTurn = game.isPlayerTurn(me)
        var g = updated
        g.calculateFieldValues()
        game = g
        // Keep the Games list in sync while this screen is open — previously
        // only `finishGame` below did this, so an opponent's move that just
        // flipped the turn back to you (without ending the game) updated
        // this screen but left the list showing "opponent's turn" until the
        // next unrelated refresh caught up.
        onGamePersisted(g)

        if let opponent, let lastOpponentTurn = g.turns(for: opponent).last {
            let value = g.isHit(lastOpponentTurn, by: opponent)
            if value == 9 {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }

        if g.isFinished {
            finishGame(winner: g.isPlayerWinner(me) ? me : (opponent ?? me))
        } else if !wasMyTurn && g.isPlayerTurn(me) {
            isTargetGridEnabled = true
            actionText = String(localized: "your_turn")
            actionIsRed = false
            showOverviewButton = true
            beginTurnTimer()
            loadCoins()
        }
    }
}

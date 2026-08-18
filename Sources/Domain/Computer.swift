import Foundation

/// Local AI opponent for offline/vs-computer games. Never sent to the server —
/// only `player` (a plain "Computer" `Player`) is ever assigned into `Game.player2`.
final class Computer {
    let player = Player(name: "Computer")
    let level: GameMode
    private(set) var shipSet: Set<Ship> = []

    /// -1 means "not yet fired at". A fired cell always holds its real hint
    /// value (0-3, or 9 for a hit) — 0 is a legitimate result, not a sentinel,
    /// so it must stay distinguishable from "unfired" or the AI can mistake
    /// an already-resolved cell for a fresh target forever.
    private var fieldsFired = Array(repeating: Array(repeating: -1, count: Constants.numFields), count: Constants.numFields)
    private var xNoMoreHits: Set<Int> = []
    private var yNoMoreHits: Set<Int> = []
    private var xOneHit: Set<Int> = []
    private var yOneHit: Set<Int> = []

    init(level: GameMode) {
        self.level = level
        while shipSet.count < Constants.numShips {
            let x = Int.random(in: 0..<Constants.numFields)
            let y = Int.random(in: 0..<Constants.numFields)
            shipSet.insert(Ship(x: x, y: y))
        }
    }

    /// Picks the computer's next shot (KI), matching the Android `getTurn()`.
    ///
    /// Prefers cells outside the rows/columns already proven empty by
    /// `xNoMoreHits`/`yNoMoreHits`, but that heuristic can (rarely) rule out
    /// every remaining unfired cell before the game is actually won — e.g. if
    /// the only columns/rows left standing happen to already be fired on. A
    /// random-retry loop with no fallback would then spin forever on the main
    /// actor and freeze the app, so this always falls back to any unfired
    /// cell instead of looping indefinitely.
    func nextTurn() -> Turn {
        var unfired: [Turn] = []
        var preferred: [Turn] = []
        for x in 0..<Constants.numFields {
            for y in 0..<Constants.numFields {
                guard fieldsFired[x][y] == -1 else { continue }
                let turn = Turn(x: x, y: y)
                unfired.append(turn)
                if !xNoMoreHits.contains(x) && !yNoMoreHits.contains(y) {
                    preferred.append(turn)
                }
            }
        }
        let candidates = preferred.isEmpty ? unfired : preferred
        return candidates.randomElement() ?? Turn(x: 0, y: 0)
    }

    func update(x: Int, y: Int, value: Int) {
        fieldsFired[x][y] = value
        switch level {
        case .computerHard:
            if value == 9 {
                if xOneHit.contains(x) { xNoMoreHits.insert(x) }
                if yOneHit.contains(y) { yNoMoreHits.insert(y) }
            }
            fallthrough
        case .computerMedium:
            if value == 0 {
                xNoMoreHits.insert(x)
                yNoMoreHits.insert(y)
            }
            if value == 1 {
                xOneHit.insert(x)
                yOneHit.insert(y)
            }
        case .computerEasy, .playerRandom, .playerSelected:
            break
        }
    }
}

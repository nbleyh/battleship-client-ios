import SwiftUI

/// Port of `GamesSelectActivity` / games_select.xml + `GamesListViewAdapter`.
/// Owns the Games tab's `NavigationPath` so nested screens (Prepare -> Game)
/// can pop all the way back to this list in one step (see `GameRoute`).
struct GamesListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                SectionDivider()

                List {
                    ForEach(appState.games) { game in
                        if let me = appState.player {
                            GameRow(game: game, me: me)
                                .listRowBackground(Theme.background)
                                .contentShape(Rectangle())
                                .onTapGesture { open(game, me: me) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await appState.refreshGames() }

                SectionDivider()

                Button("New Game") { path.append(GameRoute.prepare(existingGame: nil)) }
                    .buttonStyle(BattleshipButtonStyle())
                    .padding(.vertical, 10)
            }
            .screenBackground()
            .navigationTitle("Games")
            .navigationDestination(for: GameRoute.self) { route in
                destination(for: route)
            }
        }
        // No `.task` here on purpose. `AppState.beginLiveUpdates` already
        // does the initial fetch at launch and then keeps polling/listening
        // continuously for the whole session — a `.task`-driven refresh tied
        // to this view's appear/reappear would (a) be cancelled the moment a
        // game screen is pushed on top, exactly when it's needed most, and
        // (b) fire at the same instant you navigate back from ending your
        // own turn, racing the in-flight `processTurn` PUT and risking
        // clobbering the correct optimistic state with a stale read.
    }

    @ViewBuilder
    private func destination(for route: GameRoute) -> some View {
        if let me = appState.player {
            switch route {
            case .prepare(let existingGame):
                PrepareView(me: me, existingGame: existingGame, path: $path)
            case .computerGame(let game, let computer):
                GameView(game: game, me: me, computer: computer, path: $path)
            case .remoteGame(let game):
                GameView(game: game, me: me, path: $path)
            }
        }
    }

    private func open(_ game: Game, me: Player) {
        guard game.isPlayerTurn(me) || game.isFinished else { return }
        if game.ships(for: me).isEmpty {
            path.append(GameRoute.prepare(existingGame: game))
        } else {
            path.append(GameRoute.remoteGame(game))
        }
    }
}

private struct GameRow: View {
    let game: Game
    let me: Player

    private var isMyTurnOrFinished: Bool {
        switch game.status {
        case .waiting: return false
        case .turnPlayer1, .turnPlayer2: return game.isPlayerTurn(me)
        case .winPlayer1, .winPlayer2: return true
        }
    }

    private var iconName: String {
        if game.isFinished { return "PeaceIcon" }
        return isMyTurnOrFinished ? "TargetIcon" : "ClockIcon"
    }

    private var title: String {
        if game.isFinished {
            return game.isPlayerWinner(me)
                ? "\(game.description) - Your have won the game!"
                : "\(game.description) - Your have lost the game!"
        }
        if isMyTurnOrFinished {
            return "\(game.description) - Your turn!"
        }
        if let opponent = game.opponent(of: me) {
            return "\(game.description) - Waiting for \(opponent.name)'s turn."
        }
        return game.description
    }

    private var titleColor: Color {
        (isMyTurnOrFinished && !game.isFinished) ? .white : .gray
    }

    private var lastUpdateText: String {
        guard let date = game.lastUpdate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.dateFormat
        return "Last update on \(formatter.string(from: date))"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(iconName)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(titleColor)
                Text(lastUpdateText)
                    .font(.caption)
                    .foregroundColor(Theme.dimmedText)
            }
        }
        .padding(.vertical, 4)
    }
}

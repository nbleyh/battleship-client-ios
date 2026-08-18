import SwiftUI

/// Port of `MasterGameActivity` / `PlayerGameActivity` / `ComputerGameActivity`
/// / main.xml — the shared board screen for both a remote and a computer game.
struct GameView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: GameViewModel
    @Binding var path: NavigationPath

    init(game: Game, me: Player, computer: Computer? = nil, path: Binding<NavigationPath>) {
        let driver: GameViewModel.Driver = computer.map { .computer($0) } ?? .remote
        _viewModel = StateObject(wrappedValue: GameViewModel(game: game, me: me, driver: driver))
        self._path = path
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(viewModel.actionText)
                    .foregroundColor(viewModel.actionIsRed ? .red : .white)

                if viewModel.isTimerVisible {
                    ProgressView(value: viewModel.timerFraction)
                        .tint(Theme.progressTint)
                        .padding(.horizontal, 10)
                } else {
                    Color.clear.frame(height: 4)
                }

                myGrid

                SectionDivider()

                targetGrid

                SectionDivider()

                if viewModel.showOverviewButton {
                    Button("Overview") { goToOverview() }
                        .buttonStyle(BattleshipButtonStyle())
                }
            }
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.configure(appState: appState)
            viewModel.start()
        }
        .onDisappear { viewModel.stop() }
    }

    private var myGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<Constants.numFields, id: \.self) { x in
                HStack(spacing: 1) {
                    ForEach(0..<Constants.numFields, id: \.self) { y in
                        GridCellView(imageName: viewModel.myGridImage(x: x, y: y), size: 20)
                    }
                }
            }
        }
    }

    private var targetGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<Constants.numFields, id: \.self) { x in
                HStack(spacing: 1) {
                    ForEach(0..<Constants.numFields, id: \.self) { y in
                        GridCellView(
                            imageName: viewModel.targetGridImage(x: x, y: y),
                            size: 40,
                            isEnabled: viewModel.isTargetGridEnabled
                        ) {
                            viewModel.tapTargetCell(x: x, y: y)
                        }
                    }
                }
            }
        }
    }

    private func goToOverview() {
        // No explicit refresh here on purpose: `endMyTurn`/`finishGame`
        // already pushed the correct state into `appState.games` the
        // instant the turn ended (see GameViewModel), well before this
        // button is even tappable. An extra `refreshGames()` fired at this
        // exact moment races the in-flight `processTurn` PUT — if the GET
        // reaches the server before that PUT commits, it reads the
        // pre-turn state and clobbers the correct optimistic update with a
        // stale one. `AppState`'s own live-update loop (push + 3s poll)
        // reconciles with the server on its own timeline; no need to race it.
        path = NavigationPath()
    }
}

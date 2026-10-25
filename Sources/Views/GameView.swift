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

                // Same row/height as the Overview button — a ZStack rather
                // than an HStack so the button stays centered exactly as
                // before (BattleshipButtonStyle doesn't fill width) while the
                // icon independently pins to the leading edge of that row.
                if viewModel.showOverviewButton || viewModel.showDoubleShotIcon {
                    ZStack {
                        if viewModel.showOverviewButton {
                            Button("Overview") { goToOverview() }
                                .buttonStyle(BattleshipButtonStyle())
                        }
                        if viewModel.showDoubleShotIcon {
                            HStack {
                                doubleShotIcon
                                Spacer()
                            }
                        }
                    }
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

    /// Status indicator only for now — not yet wired to an actual
    /// double-shot action; see PlayerGameActivity/GameView comments once
    /// that mechanic is defined.
    private var doubleShotIcon: some View {
        Image("DoubleShotIcon")
            .resizable()
            .frame(width: 40, height: 40)
            .grayscale(viewModel.canDoubleShot ? 0 : 1)
            .opacity(viewModel.canDoubleShot ? 1 : 0.5)
            .padding(.horizontal, 12)
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

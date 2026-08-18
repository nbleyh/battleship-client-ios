import SwiftUI

/// Port of `PrepareActivity` / prepare.xml.
struct PrepareView: View {
    let me: Player
    let existingGame: Game?
    @Binding var path: NavigationPath

    @EnvironmentObject private var appState: AppState
    @StateObject private var reachability = Reachability.shared
    @StateObject private var viewModel: PrepareViewModel
    @State private var showingPlayerPicker = false

    init(me: Player, existingGame: Game?, path: Binding<NavigationPath>) {
        self.me = me
        self.existingGame = existingGame
        self._path = path
        _viewModel = StateObject(
            wrappedValue: PrepareViewModel(me: me, existingGame: existingGame, isOnline: Reachability.shared.isOnline)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(viewModel.headerText)
                    .foregroundColor(.white)

                SectionDivider()

                shipGrid

                SectionDivider()

                VStack(spacing: 8) {
                    HStack {
                        Text("Opponent:").foregroundColor(.white)
                        Picker("", selection: $viewModel.gameMode) {
                            ForEach(viewModel.availableModes) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .disabled(!viewModel.isModePickerEnabled)
                        .tint(.white)
                    }

                    if viewModel.gameMode == .playerSelected {
                        HStack {
                            Text("Player:").foregroundColor(.white)
                            Text(viewModel.opponentName ?? "")
                                .foregroundColor(.white)
                                .frame(width: 200, alignment: .leading)
                        }
                    }
                }

                SectionDivider()

                Button("Start Game") { start() }
                    .buttonStyle(BattleshipButtonStyle(isEnabled: viewModel.canStart))
                    .disabled(!viewModel.canStart || viewModel.isSubmitting)

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.white)
                }
            }
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.gameMode) { newValue in
            if newValue == .playerSelected && viewModel.opponentName == nil {
                showingPlayerPicker = true
            }
        }
        .sheet(isPresented: $showingPlayerPicker) {
            PlayerPickerView(me: me) { player in
                viewModel.selectOpponent(player)
            }
        }
    }

    private var shipGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<Constants.numFields, id: \.self) { x in
                HStack(spacing: 1) {
                    ForEach(0..<Constants.numFields, id: \.self) { y in
                        GridCellView(
                            imageName: viewModel.shipCells.contains(Ship(x: x, y: y)) ? "Ship" : "Fog",
                            size: 40
                        ) {
                            viewModel.toggle(x: x, y: y)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(Theme.divider)
    }

    private func start() {
        Task {
            switch await viewModel.start(appState: appState) {
            case .localGame(let game, let computer):
                path.append(GameRoute.computerGame(game, computer))
            case .remoteGame(let game):
                path.append(GameRoute.remoteGame(game))
            case .returnedToList:
                path = NavigationPath()
            case .failed:
                break
            }
        }
    }
}

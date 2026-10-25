import SwiftUI

/// Port of `TabedActivity` (Games / Ranking / Help tab host).
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var coins: Int?

    var body: some View {
        VStack(spacing: 0) {
            if let me = appState.player, let coins {
                Text(String(format: NSLocalizedString("coins_header", comment: ""), me.name, coins))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.actionBar)
            }

            TabView {
                // GamesListView owns its own NavigationStack + path so nested
                // screens can pop straight back to the list (see GameRoute).
                GamesListView()
                    .tabItem { Label("Games", systemImage: "square.grid.3x3.fill") }

                NavigationStack {
                    RankingView()
                        .navigationTitle("Ranking")
                }
                .tabItem { Label("Ranking", systemImage: "list.number") }

                NavigationStack {
                    HelpView()
                        .navigationTitle("Help")
                }
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
            }
            .tint(Theme.accent)
        }
        .task { await loadCoins() }
    }

    private func loadCoins() async {
        guard let me = appState.player else { return }
        coins = try? await BattleshipAPI.shared.getCoins(for: me.name)
    }
}

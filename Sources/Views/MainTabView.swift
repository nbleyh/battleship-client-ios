import SwiftUI

/// Port of `TabedActivity` (Games / Ranking / Help tab host).
struct MainTabView: View {
    var body: some View {
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
}

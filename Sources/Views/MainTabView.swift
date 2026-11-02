import SwiftUI

/// Port of `TabedActivity` (Games / Ranking / Help tab host).
///
/// The coins header used to live here, as a sibling above `TabView` — but
/// that sits outside every tab's own `NavigationStack`, so it stayed on
/// screen even once a tab pushed a detail screen (a game), stacking on top
/// of that screen's own header, and it made every tab's large title sit
/// behind an extra reserved-but-empty safe-area gap (a second "nav bar"
/// above the real one). Each tab now shows the header itself instead — see
/// GamesListView/RankingView/HelpView — sourced from `appState.coins` so
/// there's still just one fetch, not three.
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

import Foundation

@MainActor
final class RankingViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var errorMessage: String?

    private let api = BattleshipAPI.shared

    func refresh() async {
        guard Reachability.shared.isOnline else { return }
        do {
            var ranked = try await api.getPlayers()
            for i in ranked.indices {
                ranked[i].rank = i + 1
            }
            players = ranked
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "app_error")
        }
    }
}

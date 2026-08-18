import Foundation

/// Port of `PlayerSelectActivity`.
@MainActor
final class PlayerPickerViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var errorMessage: String?

    private let api = BattleshipAPI.shared

    func load(excluding me: Player) async {
        do {
            var fetched = try await api.getPlayers()
            fetched.removeAll { $0.name == me.name }
            players = fetched
        } catch {
            errorMessage = "Application error occurred."
        }
    }
}

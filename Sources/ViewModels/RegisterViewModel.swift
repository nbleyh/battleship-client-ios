import Foundation

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var isRegistering = false
    @Published var errorMessage: String?

    private let api = BattleshipAPI.shared

    func register(onSuccess: @escaping (Player) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20 else {
            errorMessage = String(localized: "name_length_error")
            return
        }
        isRegistering = true
        errorMessage = nil
        Task {
            do {
                // The FCM token (if any) is attached later, once Firebase
                // finishes registering for remote notifications — see
                // PushManager.messaging(_:didReceiveRegistrationToken:).
                let player = try await api.register(Player(name: trimmed))
                isRegistering = false
                onSuccess(player)
            } catch let error as APIError where error.isPlayerAlreadyExists {
                // There's no password here — a name is the whole identity —
                // so a name that's already taken is, in practice, just as
                // likely to be this same person signing back in after their
                // locally saved name got lost (a reinstall, or AppState
                // wiping it after a network hiccup once did exactly this)
                // as it is a genuine collision. Fetch and sign in as that
                // player instead of dead-ending on an error with no way back
                // into an account that's still sitting on the server.
                if let existingPlayer = try? await api.getPlayer(named: trimmed) {
                    isRegistering = false
                    onSuccess(existingPlayer)
                } else {
                    isRegistering = false
                    errorMessage = String(format: NSLocalizedString("player_already_exists", comment: ""), trimmed)
                }
            } catch {
                isRegistering = false
                errorMessage = String(localized: "app_error")
            }
        }
    }
}

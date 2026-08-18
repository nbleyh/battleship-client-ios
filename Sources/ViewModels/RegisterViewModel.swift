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
            errorMessage = "The name has to be between 1 and 20 characters long."
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
                isRegistering = false
                errorMessage = "Player '\(trimmed)' does already exist."
            } catch {
                isRegistering = false
                errorMessage = "Application error occurred."
            }
        }
    }
}

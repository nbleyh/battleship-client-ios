import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

/// Wraps Firebase Cloud Messaging + local notification presentation. Replaces
/// Android's `BattleshipFirebaseService` (token refresh, message receipt) and
/// the notification-posting half of `UpdatedGameReceiver`.
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    /// Set once the signed-in player is known, so a refreshed FCM token can be
    /// pushed to the server (mirrors Android's `NewTokenReceiver`).
    var currentPlayer: Player?

    private override init() {
        super.init()
    }

    func configure() {
        guard FirebaseConfig.isConfigured else { return }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationAndRegister() {
        guard FirebaseConfig.isConfigured else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
                PushManager.shared.syncCurrentToken()
            }
        }
    }

    /// Explicitly fetches FCM's current (possibly already-cached) token and
    /// sends it to the server. `didReceiveRegistrationToken` below only fires
    /// on an actual token *change* — if Firebase minted the token at launch,
    /// before `currentPlayer` was known (e.g. `configure()` wiring up the
    /// delegate happens well before `AppState` finishes fetching the signed-in
    /// player), that one-shot event already fired into a no-op and the server
    /// never learned the token, leaving `firebase_token` empty forever for
    /// this install — mirrors Android's analogous `syncCurrentFcmToken`.
    private func syncCurrentToken() {
        Messaging.messaging().token { [weak self] token, _ in
            guard let token else { return }
            Task { @MainActor in
                guard var player = self?.currentPlayer, player.firebaseToken != token else { return }
                player.firebaseToken = token
                self?.currentPlayer = player
                _ = try? await BattleshipAPI.shared.updatePlayer(player)
            }
        }
    }

    /// Handles a "your turn" push (foreground or background data message):
    /// fetches the full updated game, broadcasts it locally via
    /// `GameUpdateCenter` (mirroring `BattleshipFirebaseService.onMessageReceived`),
    /// and — since the server sends a data-only message with no `notification`
    /// payload, which iOS never displays on its own — posts a local
    /// notification exactly when Android's `GameNotificationHelper.notifyYourTurn`
    /// would (skipped once the game is finished or it's not actually this
    /// player's turn, e.g. the push arrived late after another refresh already
    /// moved things along).
    func handleRemoteMessage(_ userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo["updated_game"] as? String, let gameId = Int(idString) else { return }
        Task {
            guard let game = try? await BattleshipAPI.shared.getGame(gameId) else { return }
            await MainActor.run {
                GameUpdateCenter.post(game)
                if let me = currentPlayer, !game.isFinished, game.isPlayerTurn(me) {
                    postLocalNotification(for: game)
                }
            }
        }
    }

    private func postLocalNotification(for game: Game) {
        let content = UNMutableNotificationContent()
        content.title = "Your turn!"
        content.body = game.description
        content.sound = .default
        let request = UNNotificationRequest(identifier: "game-\(game.gameId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension PushManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            guard var player = PushManager.shared.currentPlayer else { return }
            player.firebaseToken = token
            PushManager.shared.currentPlayer = player
            _ = try? await BattleshipAPI.shared.updatePlayer(player)
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Task { @MainActor in PushManager.shared.handleRemoteMessage(userInfo) }
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in PushManager.shared.handleRemoteMessage(userInfo) }
        completionHandler()
    }
}

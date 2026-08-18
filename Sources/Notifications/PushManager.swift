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
            }
        }
    }

    /// Handles a "your turn" push (foreground or background data message):
    /// fetches the full updated game and broadcasts it locally via
    /// `GameUpdateCenter`, mirroring `BattleshipFirebaseService.onMessageReceived`.
    func handleRemoteMessage(_ userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo["updated_game"] as? String, let gameId = Int(idString) else { return }
        Task {
            if let game = try? await BattleshipAPI.shared.getGame(gameId) {
                await MainActor.run { GameUpdateCenter.post(game) }
            }
        }
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

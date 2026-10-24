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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error {
                print("PushManager: notification authorization request failed: \(error)")
                Task { @MainActor in self?.postDiagnosticNotification("Authorization request failed: \(error.localizedDescription)") }
            }
            guard granted else {
                print("PushManager: notification authorization denied — no token will be registered")
                return
            }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
                // Deliberately NOT calling syncCurrentToken() here: the APNs
                // device token this depends on hasn't round-tripped to Apple's
                // servers yet (registerForRemoteNotifications() only *starts*
                // that, asynchronously) — AppDelegate's
                // didRegisterForRemoteNotificationsWithDeviceToken is the
                // actual signal that Messaging.apnsToken is set and a real FCM
                // token can be requested.
            }
        }
    }

    /// Called from AppDelegate once the APNs device token is confirmed set on
    /// `Messaging.messaging()` — the earliest point a real FCM token can
    /// actually be generated. Explicitly fetches it and sends it to the
    /// server rather than relying solely on `didReceiveRegistrationToken`
    /// below, which only fires on a token *change*: if Firebase already had a
    /// cached token from a previous install, nothing "changes" and that
    /// one-shot event never fires, leaving `firebase_token` empty forever —
    /// mirrors Android's analogous `syncCurrentFcmToken`.
    func syncCurrentToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("PushManager: fetching FCM token failed: \(error)")
                Task { @MainActor in self?.postDiagnosticNotification("Fetching FCM token failed: \(error.localizedDescription)") }
                return
            }
            guard let token else {
                print("PushManager: fetching FCM token returned no token and no error")
                Task { @MainActor in self?.postDiagnosticNotification("Fetching FCM token returned nothing, no error given.") }
                return
            }
            Task { @MainActor in
                guard var player = self?.currentPlayer else {
                    print("PushManager: got FCM token but no signed-in player yet, dropping it")
                    self?.postDiagnosticNotification("Got FCM token but no signed-in player yet.")
                    return
                }
                guard player.firebaseToken != token else { return }
                player.firebaseToken = token
                self?.currentPlayer = player
                do {
                    _ = try await BattleshipAPI.shared.updatePlayer(player)
                } catch {
                    print("PushManager: sending FCM token to server failed: \(error)")
                    self?.postDiagnosticNotification("Sending FCM token to server failed: \(error.localizedDescription)")
                }
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
        content.title = String(localized: "your_turn")
        content.body = game.description
        content.sound = .default
        let request = UNNotificationRequest(identifier: "game-\(game.gameId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// TEMPORARY — push registration has been silently failing in the field
    /// with no way to see why (TestFlight only, no cable on hand to watch the
    /// Xcode console). Surfaces the failure as a visible notification instead,
    /// so it can be read directly off the device. Remove once push
    /// registration is confirmed reliably working again.
    private func postDiagnosticNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Push setup failed"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: "push-diagnostic-\(UUID())", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension PushManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            guard var player = PushManager.shared.currentPlayer else {
                print("PushManager: FCM token changed but no signed-in player yet, dropping it")
                return
            }
            player.firebaseToken = token
            PushManager.shared.currentPlayer = player
            do {
                _ = try await BattleshipAPI.shared.updatePlayer(player)
            } catch {
                print("PushManager: sending refreshed FCM token to server failed: \(error)")
            }
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

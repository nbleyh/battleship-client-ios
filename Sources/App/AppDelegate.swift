import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if FirebaseConfig.isConfigured {
            FirebaseApp.configure()
        }
        Task { @MainActor in
            PushManager.shared.configure()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        // This is the earliest point a real FCM token can be generated — see
        // the comment on PushManager.syncCurrentToken() for why it isn't
        // called any earlier (e.g. right after requestAuthorizationAndRegister's
        // registerForRemoteNotifications() call).
        Task { @MainActor in
            PushManager.shared.syncCurrentToken()
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push won't be available; the rest of the app is unaffected. Logged
        // (rather than silently discarded) since this is otherwise invisible —
        // e.g. a provisioning profile missing the Push Notifications
        // entitlement fails exactly here, with no other visible symptom.
        print("AppDelegate: APNs registration failed: \(error)")
        // TEMPORARY diagnostic — see PushManager.postDiagnosticNotification.
        let content = UNMutableNotificationContent()
        content.title = "Push setup failed"
        content.body = "APNs registration failed: \(error.localizedDescription)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "push-diagnostic-apns-\(UUID())", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            PushManager.shared.handleRemoteMessage(userInfo)
        }
        completionHandler(.newData)
    }
}

import Foundation

enum FirebaseConfig {
    /// True once a real `GoogleService-Info.plist` (downloaded from the
    /// Firebase console after registering this app's iOS bundle ID under the
    /// existing "russian-battleship" project) has been added to the project.
    /// Until then, push notification code is skipped entirely so the rest of
    /// the app still works.
    static var isConfigured: Bool {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let appId = dict["GOOGLE_APP_ID"] as? String,
              !appId.contains("REPLACE_ME") else {
            return false
        }
        return true
    }
}

import Foundation

/// Replaces the Android app's `config.txt` + XOR `Encoder` file storage. The
/// player's name is not sensitive (there's no password), so plain
/// `UserDefaults` is sufficient — the original obfuscation was never a real
/// security measure.
enum PlayerStore {
    static func savedPlayerName() -> String? {
        UserDefaults.standard.string(forKey: Constants.playerNameDefaultsKey)
    }

    static func save(playerName: String) {
        UserDefaults.standard.set(playerName, forKey: Constants.playerNameDefaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Constants.playerNameDefaultsKey)
    }
}

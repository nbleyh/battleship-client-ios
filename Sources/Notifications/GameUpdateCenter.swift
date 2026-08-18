import Foundation

/// Replaces Android's `LocalBroadcastManager` / `UpdatedGameReceiver`: an
/// in-process pub/sub so any active screen (games list, an open game board)
/// learns about a game update, whether it came from a push notification, a
/// poll, or our own move.
enum GameUpdateCenter {
    static let gameUpdatedNotification = Notification.Name("com.nick.shipbattle.gameUpdated")
    static let gameUserInfoKey = "game"

    static func post(_ game: Game) {
        NotificationCenter.default.post(
            name: gameUpdatedNotification,
            object: nil,
            userInfo: [gameUserInfoKey: game]
        )
    }

    /// Async stream of game updates, for use with `for await` in a view model's task.
    static var updates: AsyncStream<Game> {
        AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: gameUpdatedNotification,
                object: nil,
                queue: nil
            ) { notification in
                if let game = notification.userInfo?[gameUserInfoKey] as? Game {
                    continuation.yield(game)
                }
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

import Foundation
import Network

/// Lightweight network-reachability observer, replacing the Android
/// `ConnectivityManager`-based `isOnline()` checks used to decide whether
/// player-vs-player game modes should be offered.
@MainActor
final class Reachability: ObservableObject {
    static let shared = Reachability()

    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.nick.shipbattle.reachability")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}

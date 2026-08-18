import Foundation

/// App-wide session state: which player is signed in and their games list.
/// Replaces `StartActivity`'s launch flow (read saved player -> fetch player
/// -> fetch games) plus the bits of `Player.myGames` that every screen needs.
@MainActor
final class AppState: ObservableObject {
    enum Phase {
        case loading
        case needsRegistration
        case ready
    }

    @Published private(set) var phase: Phase = .loading
    @Published var player: Player?
    @Published var games: [Game] = []

    private let api = BattleshipAPI.shared
    /// Keeps `games` current for as long as the app is signed in, independent
    /// of which tab or nested game screen is on screen. `GamesListView` used
    /// to own this loop inside a `.task`, but `.task` is cancelled as soon as
    /// that view is pushed behind a nested destination (opening a game) —
    /// exactly when a status change is most likely to arrive — so the list
    /// could sit stale until the user backed all the way out. Owning it here
    /// means it keeps running regardless of navigation.
    private var liveUpdatesTask: Task<Void, Never>?

    func start() {
        Task { await loadInitialState() }
    }

    private func loadInitialState() async {
        guard let name = PlayerStore.savedPlayerName() else {
            phase = .needsRegistration
            return
        }
        do {
            let fetchedPlayer = try await api.getPlayer(named: name)
            player = fetchedPlayer
            PushManager.shared.currentPlayer = fetchedPlayer
            PushManager.shared.requestAuthorizationAndRegister()
            await refreshGames()
            phase = .ready
            beginLiveUpdates()
        } catch {
            // Player no longer exists on the server (or the fetch failed) —
            // fall back to registration, mirroring StartActivity.onResponse.
            PlayerStore.clear()
            phase = .needsRegistration
        }
    }

    func didRegister(player registeredPlayer: Player) {
        PlayerStore.save(playerName: registeredPlayer.name)
        player = registeredPlayer
        PushManager.shared.currentPlayer = registeredPlayer
        PushManager.shared.requestAuthorizationAndRegister()
        Task {
            await refreshGames()
            phase = .ready
            beginLiveUpdates()
        }
    }

    /// Starts (once) the push-driven + polling fallback that keeps `games`
    /// current. Safe to call repeatedly — a second call is a no-op while the
    /// loop is already running.
    private func beginLiveUpdates() {
        guard liveUpdatesTask == nil else {
            print("DEBUGLOG beginLiveUpdates: already running, skipping")
            return
        }
        print("DEBUGLOG beginLiveUpdates: starting")
        liveUpdatesTask = Task { [weak self] in
            // Unwrap once into an immutable `let self` — re-reading the weak
            // (mutable) capture from inside the `async let` child tasks below
            // is what Swift 6 flags as a data race ("reference to captured
            // var 'self' in concurrently-executing code").
            guard let self else { return }
            async let pushDriven: Void = {
                for await _ in GameUpdateCenter.updates {
                    await self.refreshGames()
                }
            }()
            // Push is the fast path, but it depends on Firebase being
            // configured and on APNs/FCM actually delivering to this device —
            // neither is guaranteed (see GameViewModel.beginPolling). Without
            // this fallback, the list can be stuck showing a stale turn
            // indefinitely even after the opponent has moved server-side.
            async let polling: Void = {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if Task.isCancelled { return }
                    await self.refreshGames()
                }
            }()
            _ = await (pushDriven, polling)
        }
    }

    func refreshGames() async {
        guard let player else { return }
        do {
            let fetched = try await api.getGames(for: player.name)
            print("DEBUGLOG refreshGames OK: \(fetched.map { ($0.gameId, $0.status.rawValue) })")
            games = Game.sortedByRecency(fetched)
        } catch {
            print("DEBUGLOG refreshGames FAILED: \(error)")
        }
    }

    /// Reflects a locally created/updated game immediately, without waiting
    /// for the next full refresh.
    func upsert(_ game: Game) {
        print("DEBUGLOG upsert: gameId=\(game.gameId) status=\(game.status.rawValue)")
        if let index = games.firstIndex(where: { $0.gameId == game.gameId }) {
            games[index] = game
        } else {
            games.insert(game, at: 0)
        }
        games = Game.sortedByRecency(games)
    }
}

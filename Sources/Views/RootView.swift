import SwiftUI

/// Port of `StartActivity`'s routing decision (registration vs. main app).
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .loading:
                ZStack {
                    Theme.background.ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            case .needsRegistration:
                RegisterView()
            case .ready:
                MainTabView()
            }
        }
        .onAppear { appState.start() }
        .preferredColorScheme(.dark)
    }
}

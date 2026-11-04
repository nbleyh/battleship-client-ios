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
            case .connectionError:
                ZStack {
                    Theme.background.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("connection_error")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Retry") { appState.start() }
                            .buttonStyle(BattleshipButtonStyle())
                    }
                }
            }
        }
        .onAppear { appState.start() }
        .preferredColorScheme(.dark)
    }
}

import SwiftUI

/// Port of `RegisterActivity` / activity_register.xml.
struct RegisterView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RegisterViewModel()
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Name:")
                    .foregroundColor(.white)
                TextField("", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .disabled(viewModel.isRegistering)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(submit)
            }
            .padding(.horizontal, 10)
            .padding(.top, 24)
            .padding(.bottom, 12)

            SectionDivider()

            Button("Register", action: submit)
                .buttonStyle(BattleshipButtonStyle(isEnabled: !viewModel.isRegistering))
                .disabled(viewModel.isRegistering)
                .padding(.top, 12)

            if let message = viewModel.errorMessage {
                Text(message)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Spacer()
        }
        .screenBackground()
        .onAppear { nameFieldFocused = true }
    }

    private func submit() {
        viewModel.register { player in
            appState.didRegister(player: player)
        }
    }
}

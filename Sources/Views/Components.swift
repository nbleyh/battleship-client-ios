import SwiftUI

struct BattleshipButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .white : .gray)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.buttonBackground)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionDivider: View {
    var body: some View {
        Rectangle().fill(Theme.divider).frame(height: 2)
    }
}

/// Right-aligned "name: N Coins" bar — shown atop each of the three main
/// tabs (sourced from `AppState.coins`) and atop the game screen (sourced
/// from `GameViewModel.coins`, which also drives double-shot eligibility).
struct CoinsHeader: View {
    let name: String
    let coins: Int

    var body: some View {
        Text(String(format: NSLocalizedString("coins_header", comment: ""), name, coins))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.actionBar)
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}

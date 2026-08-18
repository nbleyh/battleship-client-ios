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

import SwiftUI

/// One battlefield cell — a fixed-size ported Android drawable, optionally
/// tappable. Matches Android's FieldStyle (40dp) / FieldStyleSmall (20dp).
struct GridCellView: View {
    let imageName: String
    var size: CGFloat = 40
    var isEnabled: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            Image(imageName)
                .resizable()
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(action == nil || !isEnabled)
        .background(Theme.background)
    }
}

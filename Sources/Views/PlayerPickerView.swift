import SwiftUI

/// Port of `PlayerSelectActivity` / player_select.xml, presented as a sheet.
struct PlayerPickerView: View {
    let me: Player
    let onSelect: (Player) -> Void

    @StateObject private var viewModel = PlayerPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SectionDivider()
                List(viewModel.players) { player in
                    Text(player.name)
                        .foregroundColor(.white)
                        .listRowBackground(Theme.background)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(player)
                            dismiss()
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .screenBackground()
            .navigationTitle("Select Player")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.load(excluding: me) }
    }
}

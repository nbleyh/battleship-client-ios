import SwiftUI

/// Port of `RankingActivity` / ranking.xml + `RankingListViewAdapter`.
/// Column order (Rank, Player, Played, Won) matches ranking_list_header.xml.
struct RankingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RankingViewModel()

    /// `Rank`/`Played`/`Won` are 1 unit wide, `Player` is 2 units — 5 units
    /// total, matching `ListTextStyle`'s default `layout_weight="1"` vs.
    /// `nameHeader`/`name`'s `layout_weight="2"` in the Android layouts.
    /// Computed from the actual screen width via `GeometryReader` so the row
    /// still spans the full content width (fixed pixel widths for every
    /// column would leave the row narrower than the screen with blank space
    /// on the trailing edge).
    ///
    /// All four columns are left-aligned, not centered: `ListTextStyle` sets
    /// no `gravity`, so Android's default `TextView` start-alignment applies
    /// to every cell, header row included.
    ///
    /// The 10pt side margin and the 1pt row divider (`Theme.divider`, i.e.
    /// `#37495D`) mirror `ranking.xml`'s `ListView` (`layout_marginLeft/Right
    /// ="10dp"`, `divider="#37495D"`, `dividerHeight="1dp"`) — the header
    /// there is added via `addHeaderView`, so it's a row in that same list
    /// and gets the identical margin and a divider under it too.
    private let horizontalPadding: CGFloat = 10
    private let cellInset: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            SectionDivider()

            GeometryReader { geo in
                let columnWidth = (geo.size.width - horizontalPadding * 2) / 5

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        header("ranking_header_rank", width: columnWidth)
                        header("ranking_header_player", width: columnWidth * 2)
                        header("ranking_header_played", width: columnWidth)
                        header("ranking_header_won", width: columnWidth)
                    }
                    .background(Theme.buttonBackground)

                    Rectangle().fill(Theme.divider).frame(height: 1)

                    List(viewModel.players) { player in
                        let isMe = appState.player?.name == player.name
                        HStack(spacing: 0) {
                            cell(String(player.rank), width: columnWidth, isMe: isMe)
                            cell(player.name, width: columnWidth * 2, isMe: isMe)
                            cell(String(player.played), width: columnWidth, isMe: isMe)
                            cell(String(player.won), width: columnWidth, isMe: isMe)
                        }
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.divider)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await viewModel.refresh() }
                }
                .padding(.horizontal, horizontalPadding)
            }

            SectionDivider()
        }
        .screenBackground()
        .task { await viewModel.refresh() }
    }

    private func header(_ text: LocalizedStringKey, width: CGFloat) -> some View {
        Text(text)
            .bold()
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.leading, cellInset)
            .frame(width: width, alignment: .leading)
    }

    private func cell(_ text: String, width: CGFloat, isMe: Bool) -> some View {
        Text(text)
            .foregroundColor(isMe ? .white : Theme.dimmedText)
            .padding(.leading, cellInset)
            .frame(width: width, alignment: .leading)
    }
}

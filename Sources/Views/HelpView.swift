import SwiftUI

/// Port of `HelpActivity` / help.xml (static rules text, verbatim).
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionDivider()

                Text("""
                Aim of the game Ship Battle is to hit all 3 enemy ships.

                The game starts by placing your 3 ships on desired cells of your battlefield.

                Afterwards the turn switches between you and the computer. Therfore just click on an empty cell of the computers battlefield. You have 15 seconds for each turn.

                Each hit cell with no ship placed gives a hint with the numbers from 0 to 3 indicating how many cells with ships cross the current cell. The position of a ship can cross the current cell horizonal, vertical and diagonal. 0 means this cell is crossed by none ships, 1 means this cell is crossed by 1 ship, etc.
                """)
                .foregroundColor(.white)
                .padding(.horizontal, 12)

                HStack(spacing: 10) {
                    Image("Help1").resizable().aspectRatio(contentMode: .fit)
                    Image("Help2").resizable().aspectRatio(contentMode: .fit)
                }
                .padding(.horizontal, 10)
            }
            .padding(.vertical, 12)
        }
        .screenBackground()
    }
}

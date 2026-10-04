import SwiftUI

/// Port of `HelpActivity` / help.xml (static rules text, verbatim).
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionDivider()

                Text("help_text")
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

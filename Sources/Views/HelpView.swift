import SwiftUI

/// Port of `HelpActivity` / help.xml (static rules text, verbatim).
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionDivider()

                sectionHeader("help_section_1_title")

                Text("help_text")
                .foregroundColor(.white)
                .padding(.horizontal, 12)

                HStack(spacing: 10) {
                    Image("Help1").resizable().aspectRatio(contentMode: .fit)
                    Image("Help2").resizable().aspectRatio(contentMode: .fit)
                }
                .padding(.horizontal, 10)

                SectionDivider()

                sectionHeader("help_section_2_title")

                Text("help_coins_text")
                .foregroundColor(.white)
                .padding(.horizontal, 12)

                HStack(spacing: 12) {
                    Image("DoubleShotIcon")
                        .resizable()
                        .frame(width: 40, height: 40)
                    Text("help_double_shot_label")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        }
        .screenBackground()
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.title3)
            .bold()
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
    }
}

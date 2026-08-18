import SwiftUI

/// Color palette ported from the Android app's styles.xml / colors.xml.
enum Theme {
    static let background = Color(hex: 0x1E253F)
    static let divider = Color(hex: 0x37495D)
    static let actionBar = Color(hex: 0x37495D)
    static let buttonBackground = Color(hex: 0x7E959B)
    static let progressTrack = Color(hex: 0x7E959B)
    static let progressTint = Color(hex: 0xB9CAC0)
    static let text = Color.white
    static let dimmedText = Color.gray
    static let accent = Color(hex: 0x03DAC5)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

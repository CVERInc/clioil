import SwiftUI

// reepub-inspired palette (its brand tokens): deep teal-black ground, mint text,
// teal accent, with green/amber/red for state.
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let reefGround   = Color(hex: 0x04181a)   // window background (deep teal-black)
    static let reefDeep     = Color(hex: 0x052f30)   // panels / sidebar
    static let reefTeal     = Color(hex: 0x0a8c8e)   // primary accent
    static let reefMint     = Color(hex: 0xaceace)   // headings / highlights
    static let reefText     = Color(hex: 0xe6f4f3)   // primary text
    static let reefTextDim  = Color(hex: 0xe6f4f3).opacity(0.62)
    static let reefBorder   = Color(hex: 0xaceace).opacity(0.18)
    static let reefGreen    = Color(hex: 0x10b981)   // ready / clean
    static let reefAmber    = Color(hex: 0xf59e0b)   // warning
    static let reefRed      = Color(hex: 0xef4444)   // error
}

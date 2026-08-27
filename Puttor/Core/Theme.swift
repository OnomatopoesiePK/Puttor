//
//  Theme.swift
//  Puttor
//

import SwiftUI

enum Theme {
    /// Dark: deepened background + brighter text/borders for higher contrast
    /// (used outdoors, so glare/direct sun readability matters).
    /// Light: near-white background + near-black ink, colors darkened so
    /// they still meet a good contrast ratio as text/icons on white.
    private static var isDark: Bool { ThemeManager.shared.isDark }
    private static func t(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(hex: isDark ? dark : light)
    }

    // Base
    static var background: Color { t(0x081420, 0xFFFFFF) }
    static var surface: Color { t(0x16273A, 0xF1F4F6) }
    static var surfaceElevated: Color { t(0x1F3548, 0xE4E9EC) }
    static var card: Color { t(0x121F2E, 0xF7F9FA) }

    // Brand
    static var primary: Color { t(0x3DBA6F, 0x1F7A45) }
    static var primaryDark: Color { t(0x2A8B52, 0x14602F) }
    static var primaryLight: Color { t(0x52D687, 0x3DBA6F) }
    static var accent: Color { t(0xFFB84D, 0xB86A0A) }

    // Text
    static var text: Color { t(0xFFFFFF, 0x0B1620) }
    static var textSecondary: Color { t(0xB9CEDC, 0x3E5768) }
    static var textMuted: Color { t(0x7C93A3, 0x6B8194) }

    // Status
    static var error: Color { t(0xFF5C6C, 0xD62839) }
    static var warning: Color { t(0xFFB84D, 0xA8650A) }
    static var success: Color { t(0x3DBA6F, 0x1F7A45) }
    static var border: Color { t(0x4C8039, 0xB9CDB0) }
    static var borderLight: Color { t(0x2A4A61, 0xDCE6D6) }

    // Break colours
    static var breakLeft: Color { t(0x6FA8FF, 0x1D5FCC) }
    static var breakRight: Color { t(0xFF8552, 0xC7431A) }
    static var uphill: Color { t(0x5BE7C4, 0x0E8F73) }
    static var downhill: Color { t(0xFF9E7D, 0xC24A26) }

    // Dartboard
    static var holed: Color { t(0x3DBA6F, 0x1F7A45) }
    static var lipOut: Color { t(0xFFB84D, 0xB86A0A) }
    static var missRed: Color { t(0xFF5C6C, 0xD62839) }
    static var missBlue: Color { t(0x6FA8FF, 0x1D5FCC) }

    // Miss-board sectors. Light mode borrows the slope grid artwork's own
    // palette — steel blue, plum and rust — so the two controls read as one
    // system on a light card; dark mode keeps its deeper, flatter tones.
    // Each pair alternates around the ring.
    static var missSectorBlueA: Color { t(0x3A5060, 0x50748F) }
    static var missSectorBlueB: Color { t(0x2E3F50, 0x446780) }
    static var missSectorPlumA: Color { t(0x3E3040, 0x59395D) }
    static var missSectorPlumB: Color { t(0x322635, 0x4B3050) }
    static var missSectorRustA: Color { t(0x3A2A20, 0x79411E) }
    static var missSectorRustB: Color { t(0x2E201A, 0x673619) }
    static var missLipIdle: Color { t(0x2A3D2A, 0x3F6B45) }
    static var missHoledIdle: Color { t(0x1E3A28, 0x2C6440) }

    // Break strength is drawn in the slope grid artwork's own colours, one per
    // step out from the middle: flat, 1, 2, 3, and more than 3 percent. Same
    // values in both themes, since the grid is one image either way.
    static let slopeClassColors: [Color] = [
        Color(hex: 0xADE9E6), // flat
        Color(hex: 0x4F748F), // 1
        Color(hex: 0x59395D), // 2
        Color(hex: 0x78401E), // 3
        Color(hex: 0x981B25), // more than 3
    ]

    // Length keeps one blue and varies its opacity, which separates near from
    // far more clearly than a hue shift does.
    static var dispersionLengthLow: Color { t(0x7FBBFF, 0x1D5FCC) }
    static var dispersionLengthHigh: Color { t(0x7FBBFF, 0x1D5FCC) }

    // Putt-for score category (eagle -> double+, best to worst)
    static var categoryEagle: Color { t(0xF5D26B, 0x9A7A0A) }
    static var categoryBirdie: Color { t(0xFF5C6C, 0xD62839) }
    static var categoryBogey: Color { t(0xC24A56, 0x8A2530) }
    static var categoryDoubleOrWorse: Color { t(0x7A2E38, 0x4A1219) }
    static var categoryTripleOrWorse: Color { t(0x561E26, 0x2E0A0F) }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 28
        static let full: CGFloat = 9999
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    func opacity8(_ percent: Double) -> Color {
        self.opacity(percent)
    }
}

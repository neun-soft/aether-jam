import SwiftUI

// MARK: - Color from hex / rgba

extension Color {
    init(hex: String, opacity: Double = 1) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b: Double
        if h.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(rgb: (Double, Double, Double), opacity: Double = 1) {
        self.init(.sRGB, red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, opacity: opacity)
    }
}

// MARK: - Theme tokens

enum Theme {
    // Background gradient (168deg top→bottom)
    static let bgTop = Color(hex: "12151f")
    static let bgBottom = Color(hex: "0a0c12")

    static var bgGradient: LinearGradient {
        LinearGradient(
            stops: [.init(color: bgTop, location: 0), .init(color: bgBottom, location: 1)],
            startPoint: UnitPoint(x: 0.10, y: 0),   // ~168deg
            endPoint: UnitPoint(x: -0.10, y: 1)
        )
    }

    // Surfaces
    static let panel = Color(hex: "161a24")
    static let panelAlt = Color(hex: "13161e")
    static let subtle = Color.white.opacity(0.025)
    static let inset = Color(hex: "1c212d")

    // Hairlines
    static func hairline(_ a: Double = 0.06) -> Color { Color.white.opacity(a) }

    // Text scale
    static let textPrimary = Color(hex: "eef1f7")
    static let textSecondary = Color(hex: "cfd4dd")
    static let textMuted = Color(hex: "9aa0ad")
    static let textDim = Color(hex: "6c7689")
    static let textFaint = Color(hex: "5a606e")
    static let textFainter = Color(hex: "4a505e")
    static let statusBar = Color(hex: "e6e9f0")

    static let rec = Color(hex: "e8553a")
    static let neutral = Color(hex: "8b94a6")

    // Radii
    static let rFrame: CGFloat = 46
    static let rCard: CGFloat = 18
    static let rRow: CGFloat = 16
    static let rPill: CGFloat = 11
    static let rPad: CGFloat = 13
    static let rSmall: CGFloat = 9
}

// MARK: - Layer accents

enum LayerKind: String, CaseIterable, Identifiable, Codable {
    case bass, chords, drums, lead
    var id: String { rawValue }

    var title: String { rawValue.uppercased() }

    var hex: String {
        switch self {
        case .bass: return "5b9dff"
        case .chords: return "c79bff"
        case .drums: return "7fd6a0"
        case .lead: return "e8c07d"
        }
    }

    var rgb: (Double, Double, Double) {
        switch self {
        case .bass: return (91, 157, 255)
        case .chords: return (199, 155, 255)
        case .drums: return (127, 214, 160)
        case .lead: return (232, 192, 125)
        }
    }

    var accent: Color { Color(hex: hex) }
    func tint(_ a: Double) -> Color { Color(rgb: rgb, opacity: a) }
}

// MARK: - Fonts (Space Grotesk display / JetBrains Mono data, with system fallback)

enum AppFont {
    static let display = "Space Grotesk"
    static let mono = "JetBrains Mono"

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(display, size: size).weight(weight)
    }

    static func data(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(mono, size: size).weight(weight)
    }
}

extension Text {
    func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Text {
        self.font(AppFont.ui(size, weight))
    }
    func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Text {
        self.font(AppFont.data(size, weight))
    }
}

extension View {
    /// Tracking (letter-spacing) helper matching the mock's mono captions.
    func track(_ value: CGFloat) -> some View { self.tracking(value) }
}

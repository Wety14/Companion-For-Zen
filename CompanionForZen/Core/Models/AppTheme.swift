import Foundation
import SwiftUI

public enum ZenThemePreset: String, Codable, CaseIterable, Identifiable {
    case twilight = "Twilight"
    case coral = "Coral"
    case forest = "Forest"
    case berry = "Berry"
    case lavender = "Lavender"
    case darkAccent = "Dark Zen"
    case oledPure = "OLED Black"
    
    public var id: String { rawValue }
    
    public var accentHex: String {
        switch self {
        case .twilight: return "#537CF7"
        case .coral: return "#F76F53"
        case .forest: return "#2A9D8F"
        case .berry: return "#E76F51"
        case .lavender: return "#A06CD5"
        case .darkAccent: return "#F2F0E3"
        case .oledPure: return "#537CF7"
        }
    }
    
    public var backgroundHex: String {
        switch self {
        case .twilight: return "#0E131F"
        case .coral: return "#1F110E"
        case .forest: return "#0D1E1B"
        case .berry: return "#1F0F12"
        case .lavender: return "#160F1F"
        case .darkAccent: return "#18181B"
        case .oledPure: return "#000000"
        }
    }
    
    public var color: Color {
        Color(hex: accentHex)
    }
    
    public var backgroundColor: Color {
        Color(hex: backgroundHex)
    }
}

public typealias AppIconOption = AppIconManager.AppIcon

// Color hex helper
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 83, 124, 247) // Default to Zen blue
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

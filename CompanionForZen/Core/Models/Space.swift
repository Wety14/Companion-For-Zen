import Foundation
import SwiftUI

/// Represents a Workspace / Space in Zen Browser (Arc-like workspace organization).
/// Fully powered by the Zen Browser Gradient & Theme Generator.
public struct Space: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var iconName: String
    public var profileId: String
    public var order: Int
    public var gradientColorsHex: [String]
    public var gradientOpacity: Double
    public var gradientTexture: Double
    public var gradientScheme: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        profileId: String = "Personnel",
        order: Int = 0,
        gradientColorsHex: [String] = ["#537CF7", "#F27F59", "#CBF259"],
        gradientOpacity: Double = 0.55,
        gradientTexture: Double = 0.2,
        gradientScheme: String = "auto"
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.profileId = profileId
        self.order = order
        self.gradientColorsHex = gradientColorsHex.count >= 2 ? gradientColorsHex : Space.generateZenGradient(fromBaseHex: gradientColorsHex.first ?? "#537CF7")
        self.gradientOpacity = gradientOpacity
        self.gradientTexture = gradientTexture
        self.gradientScheme = gradientScheme
    }
    
    /// Compatibility initializer that automatically converts legacy flat colors to full Zen harmonic gradients
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        profileId: String = "Personnel",
        themeColorHex: String,
        order: Int = 0,
        gradientColorsHex: [String]? = nil,
        gradientOpacity: Double? = nil,
        gradientTexture: Double? = nil,
        gradientScheme: String? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.profileId = profileId
        self.order = order
        self.gradientOpacity = gradientOpacity ?? 0.55
        self.gradientTexture = gradientTexture ?? 0.2
        self.gradientScheme = gradientScheme ?? "auto"
        if let g = gradientColorsHex, g.count >= 2 {
            self.gradientColorsHex = g
        } else {
            self.gradientColorsHex = Space.generateZenGradient(fromBaseHex: themeColorHex)
        }
    }
    
    public var primaryColorHex: String {
        gradientColorsHex.first ?? "#537CF7"
    }
    
    public var primaryColor: Color {
        Color(hex: primaryColorHex)
    }
    
    /// Legacy alias forwarding directly to the gradient system primary color
    public var themeColorHex: String {
        get { primaryColorHex }
        set {
            if gradientColorsHex.isEmpty {
                gradientColorsHex = Space.generateZenGradient(fromBaseHex: newValue)
            } else {
                gradientColorsHex[0] = newValue
            }
        }
    }
    
    /// Gradient background faithful to the intended space colors, independent of system light/dark mode.
    public var gradientBackground: LinearGradient {
        let colors = gradientColorsHex.map { Color(hex: $0) }
        return LinearGradient(
            colors: colors.count >= 2 ? colors : [primaryColor, primaryColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Computes the average perceptual luminance (ITU-R BT.601) of the space's gradient colors in [0, 255].
    public var averageLuminance: Double {
        guard !gradientColorsHex.isEmpty else { return 128.0 }
        var totalLum: Double = 0
        for hex in gradientColorsHex {
            let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: cleanHex).scanHexInt64(&int)
            let r: Double
            let g: Double
            let b: Double
            if cleanHex.count == 6 {
                r = Double((int >> 16) & 0xFF)
                g = Double((int >> 8) & 0xFF)
                b = Double(int & 0xFF)
            } else {
                r = 128; g = 128; b = 128
            }
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            totalLum += lum
        }
        return totalLum / Double(gradientColorsHex.count)
    }
    
    /// Determines whether the gradient is considered dark based strictly on perceptual luminance.
    /// On iOS, rendering is independent of desktop's `gradientScheme` setting ("clair", "sombre", "auto")
    /// to remain fully faithful to the intended space colors regardless of device light/dark appearance.
    public var isDarkGradient: Bool {
        averageLuminance < 145.0
    }
    
    // MARK: - Codable Migration Overwriting Legacy Themes
    
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, profileId, themeColorHex, order
        case gradientColorsHex, gradientOpacity, gradientTexture, gradientScheme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Espace"
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "folder"
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId) ?? "Personnel"
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        gradientOpacity = try container.decodeIfPresent(Double.self, forKey: .gradientOpacity) ?? 0.55
        gradientTexture = try container.decodeIfPresent(Double.self, forKey: .gradientTexture) ?? 0.2
        gradientScheme = try container.decodeIfPresent(String.self, forKey: .gradientScheme) ?? "auto"
        
        // Overwrite legacy flat color representations with official Zen gradients
        if let loaded = try container.decodeIfPresent([String].self, forKey: .gradientColorsHex),
           loaded.count >= 2, Set(loaded).count > 1 {
            gradientColorsHex = loaded
        } else {
            let legacyHex = try container.decodeIfPresent(String.self, forKey: .themeColorHex) ?? "#537CF7"
            gradientColorsHex = Space.generateZenGradient(fromBaseHex: legacyHex)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(order, forKey: .order)
        try container.encode(primaryColorHex, forKey: .themeColorHex)
        try container.encode(gradientColorsHex, forKey: .gradientColorsHex)
        try container.encode(gradientOpacity, forKey: .gradientOpacity)
        try container.encode(gradientTexture, forKey: .gradientTexture)
        try container.encode(gradientScheme, forKey: .gradientScheme)
    }
    
    /// Generates a genuine 3-color Zen harmonic split-complementary gradient (+150° and +210°) from any base color
    public static func generateZenGradient(fromBaseHex hex: String) -> [String] {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b: Double
        if cleanHex.count == 6 {
            r = Double((int >> 16) & 0xFF)
            g = Double((int >> 8) & 0xFF)
            b = Double(int & 0xFF)
        } else {
            r = 83; g = 124; b = 247
        }
        
        let hsl = ColorMath.rgbToHsl(r: r, g: g, b: b)
        let h1 = (hsl.h + 150).truncatingRemainder(dividingBy: 360) / 360
        let h2 = (hsl.h + 210).truncatingRemainder(dividingBy: 360) / 360
        
        let sNew = max(0.45, min(0.85, hsl.s))
        let lNew = max(0.45, min(0.70, hsl.l))
        
        let rgb1 = ColorMath.hslToRgb(h: h1, s: sNew, l: lNew)
        let rgb2 = ColorMath.hslToRgb(h: h2, s: sNew, l: lNew)
        
        let hex0 = String(format: "#%02X%02X%02X", Int(r), Int(g), Int(b))
        let hex1 = String(format: "#%02X%02X%02X", Int(rgb1.r), Int(rgb1.g), Int(rgb1.b))
        let hex2 = String(format: "#%02X%02X%02X", Int(rgb2.r), Int(rgb2.g), Int(rgb2.b))
        return [hex0, hex1, hex2]
    }
    
    public static var defaultSpaces: [Space] {
        [
            Space(
                name: "Personnel",
                iconName: "people",
                profileId: "Personnel",
                order: 0,
                gradientColorsHex: ["#537CF7", "#F27F59", "#CBF259"],
                gradientOpacity: 0.55,
                gradientTexture: 0.2,
                gradientScheme: "auto"
            ),
            Space(
                name: "Travail",
                iconName: "briefcase",
                profileId: "Travail",
                order: 1,
                gradientColorsHex: ["#F27F59", "#CBF259", "#537CF7"],
                gradientOpacity: 0.55,
                gradientTexture: 0.2,
                gradientScheme: "auto"
            ),
            Space(
                name: "Détente",
                iconName: "game-controller",
                profileId: "Détente",
                order: 2,
                gradientColorsHex: ["#CBF259", "#537CF7", "#F27F59"],
                gradientOpacity: 0.55,
                gradientTexture: 0.2,
                gradientScheme: "auto"
            )
        ]
    }
}

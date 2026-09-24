import SwiftUI

/// Zen Browser Design System Colors, Gradients, and Styling Constants
public struct ZenDesign {
    // Brand Colors
    public static let zenCoral         = Color(hex: "#F76F53")
    public static let zenCoralLightMode = Color(hex: "#E85B3D") // Subtly deeper tone for optimal contrast and eye comfort in light mode
    public static let twilightBlue     = Color(hex: "#537CF7")
    public static let zenForest    = Color(hex: "#2A9D8F")
    public static let zenBerry     = Color(hex: "#E76F51")
    public static let zenLavender  = Color(hex: "#A06CD5")
    public static let zenCream     = Color(hex: "#F2F0E3")
    
    // Background Dark Tones
    public static let zenCharcoal  = Color(hex: "#18181B")
    public static let zenDeepDark  = Color(hex: "#09090B")
    public static let zenCardDark  = Color(hex: "#27272A")
    
    // Corner Radii
    public static let radiusCard: CGFloat = 20
    public static let radiusPill: CGFloat = 28
    public static let radiusSheet: CGFloat = 24
    
    // Shadows
    public static let glowShadowColor = Color.black.opacity(0.35)
}

public enum AppThemeMode: String, Codable, CaseIterable, Identifiable {
    case automatic = "automatic"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .automatic: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

public final class ZenThemeManager: ObservableObject {
    public static let shared = ZenThemeManager()
    
    @Published public var themeMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "zen_theme_mode")
            updateKeyboardAppearance()
            applyTheme()
        }
    }
    
    public var isDarkMode: Bool {
        get {
            switch themeMode {
            case .automatic:
                return UITraitCollection.current.userInterfaceStyle == .dark
            case .light:
                return false
            case .dark:
                return true
            }
        }
        set {
            themeMode = newValue ? .dark : .light
        }
    }
    
    // Kept for model compatibility
    @Published public var currentPreset: ZenThemePreset = .twilight
    
    private init() {
        if let savedMode = UserDefaults.standard.string(forKey: "zen_theme_mode"),
           let mode = AppThemeMode(rawValue: savedMode) {
            self.themeMode = mode
        } else if UserDefaults.standard.object(forKey: "zen_is_dark_mode") != nil {
            let wasDark = UserDefaults.standard.bool(forKey: "zen_is_dark_mode")
            self.themeMode = wasDark ? .dark : .light
        } else {
            self.themeMode = .automatic
        }
        updateKeyboardAppearance()
        applyTheme()
    }
    
    public func applyTheme() {
        let style: UIUserInterfaceStyle
        switch themeMode {
        case .automatic:
            style = .unspecified
        case .light:
            style = .light
        case .dark:
            style = .dark
        }
        
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
    
    public func updateKeyboardAppearance() {
        switch themeMode {
        case .automatic:
            UITextField.appearance().keyboardAppearance = .default
        case .light:
            UITextField.appearance().keyboardAppearance = .light
        case .dark:
            UITextField.appearance().keyboardAppearance = .dark
        }
    }
    
    public var accentColor: Color {
        switch themeMode {
        case .automatic:
            return Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(ZenDesign.zenCoral) : UIColor(ZenDesign.zenCoralLightMode)
            })
        case .light:
            return ZenDesign.zenCoralLightMode
        case .dark:
            return ZenDesign.zenCoral
        }
    }
    
    public var backgroundColor: Color {
        switch themeMode {
        case .automatic:
            return Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(Color(hex: "#0E131F")) : UIColor(Color(hex: "#F8F9FA"))
            })
        case .light:
            return Color(hex: "#F8F9FA")
        case .dark:
            return Color(hex: "#0E131F")
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch themeMode {
        case .automatic:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

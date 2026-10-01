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
            if themeMode == .automatic {
                refreshSystemThemeIfNeeded()
            }
            updateKeyboardAppearance()
            applyTheme()
            objectWillChange.send()
        }
    }
    
    /// Recorded system interface style detected via trait collections or SwiftUI environment
    @Published public private(set) var systemUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    
    /// Effective UIKit interface style for window overrides.
    /// When automatic, must return .unspecified so UIKit obeys iOS system appearance.
    public var effectiveUserInterfaceStyle: UIUserInterfaceStyle {
        switch themeMode {
        case .automatic:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    /// True when dark mode is currently active (either forced dark or automatic with system dark)
    public var isDarkMode: Bool {
        get {
            switch themeMode {
            case .dark:
                return true
            case .light:
                return false
            case .automatic:
                if systemUserInterfaceStyle != .unspecified {
                    return systemUserInterfaceStyle == .dark
                }
                return retrieveSystemStyle() == .dark
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
        
        self.systemUserInterfaceStyle = retrieveSystemStyle()
        updateKeyboardAppearance()
        applyTheme()
        
        NotificationCenter.default.addObserver(
            forName: UIScene.willConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSystemThemeIfNeeded()
            self?.applyTheme()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshSystemThemeIfNeeded()
        }
    }
    
    public func retrieveSystemStyle() -> UIUserInterfaceStyle {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                let screenStyle = windowScene.screen.traitCollection.userInterfaceStyle
                if screenStyle != .unspecified {
                    return screenStyle
                }
                let sceneStyle = windowScene.traitCollection.userInterfaceStyle
                if sceneStyle != .unspecified {
                    return sceneStyle
                }
            }
        }
        let currentTrait = UITraitCollection.current.userInterfaceStyle
        if currentTrait != .unspecified {
            return currentTrait
        }
        return .unspecified
    }
    
    public func updateSystemColorScheme(_ scheme: ColorScheme) {
        let style: UIUserInterfaceStyle = (scheme == .dark) ? .dark : .light
        if systemUserInterfaceStyle != style {
            systemUserInterfaceStyle = style
            objectWillChange.send()
            if themeMode == .automatic {
                updateKeyboardAppearance()
                applyTheme()
            }
        }
    }
    
    public func refreshSystemThemeIfNeeded() {
        let detected = retrieveSystemStyle()
        if detected != .unspecified && detected != systemUserInterfaceStyle {
            systemUserInterfaceStyle = detected
            objectWillChange.send()
            if themeMode == .automatic {
                updateKeyboardAppearance()
                applyTheme()
            }
        }
    }
    
    public func applyTheme() {
        let style = effectiveUserInterfaceStyle
        
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
        case .dark:
            UITextField.appearance().keyboardAppearance = .dark
        case .light:
            UITextField.appearance().keyboardAppearance = .light
        case .automatic:
            UITextField.appearance().keyboardAppearance = .default
        }
    }
    
    public var accentColor: Color {
        isDarkMode ? ZenDesign.zenCoral : ZenDesign.zenCoralLightMode
    }
    
    public var backgroundColor: Color {
        isDarkMode ? Color(hex: "#0E131F") : Color(hex: "#F8F9FA")
    }
    
    /// ColorScheme passed to SwiftUI `.preferredColorScheme(...)`.
    /// When automatic, MUST return nil so SwiftUI obeys the operating system appearance.
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

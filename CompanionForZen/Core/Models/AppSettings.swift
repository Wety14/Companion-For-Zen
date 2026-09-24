import Foundation

public enum AutoArchivePolicy: String, Codable, CaseIterable, Identifiable {
    case twelveHours = "12 heures"
    case twentyFourHours = "24 heures"
    case threeDays = "3 jours"
    case sevenDays = "7 jours"
    case never = "Jamais"
    
    public var id: String { rawValue }
    
    public var timeInterval: TimeInterval? {
        switch self {
        case .twelveHours: return 12 * 3600
        case .twentyFourHours: return 24 * 3600
        case .threeDays: return 3 * 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
        case .never: return nil
        }
    }
}

public struct ContentBlockerSettings: Codable, Equatable {
    public var blockAds: Bool
    public var blockTrackers: Bool
    public var blockCookieBanners: Bool
    public var totalBlockedCount: Int
    
    public init(
        blockAds: Bool = true,
        blockTrackers: Bool = true,
        blockCookieBanners: Bool = true,
        totalBlockedCount: Int = 0
    ) {
        self.blockAds = blockAds
        self.blockTrackers = blockTrackers
        self.blockCookieBanners = blockCookieBanners
        self.totalBlockedCount = totalBlockedCount
    }
}

public enum ReaderTheme: String, Codable, CaseIterable, Identifiable {
    case sepia = "Sépia"
    case dark = "Sombre"
    case oled = "OLED Noir"
    case cream = "Crème"
    
    public var id: String { rawValue }
}

public enum ReaderFont: String, Codable, CaseIterable, Identifiable {
    case system = "Système"
    case serif = "Serif"
    case monospace = "Monospace"
    
    public var id: String { rawValue }
}

public struct ReaderSettings: Codable, Equatable {
    public var theme: ReaderTheme
    public var font: ReaderFont
    public var fontSize: Double
    
    public init(
        theme: ReaderTheme = .sepia,
        font: ReaderFont = .serif,
        fontSize: Double = 18.0
    ) {
        self.theme = theme
        self.font = font
        self.fontSize = fontSize
    }
}

public struct AppSettings: Codable, Equatable {
    public var autoArchivePolicy: AutoArchivePolicy
    public var contentBlocker: ContentBlockerSettings
    public var searchConfig: SearchEngineConfig
    public var themePreset: ZenThemePreset
    public var selectedIcon: AppIconOption
    public var readerSettings: ReaderSettings
    public var requestDesktopSiteByDefault: Bool
    public var languageCode: String
    
    public init(
        autoArchivePolicy: AutoArchivePolicy = .twentyFourHours,
        contentBlocker: ContentBlockerSettings = ContentBlockerSettings(),
        searchConfig: SearchEngineConfig = SearchEngineConfig(),
        themePreset: ZenThemePreset = .twilight,
        selectedIcon: AppIconOption = .primary,
        readerSettings: ReaderSettings = ReaderSettings(),
        requestDesktopSiteByDefault: Bool = false,
        languageCode: String = "fr"
    ) {
        self.autoArchivePolicy = autoArchivePolicy
        self.contentBlocker = contentBlocker
        self.searchConfig = searchConfig
        self.themePreset = themePreset
        self.selectedIcon = selectedIcon
        self.readerSettings = readerSettings
        self.requestDesktopSiteByDefault = requestDesktopSiteByDefault
        self.languageCode = languageCode
    }
}

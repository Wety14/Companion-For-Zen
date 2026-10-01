import Foundation
import Combine

public enum SearchEngineType: String, Codable, CaseIterable, Identifiable {
    case duckDuckGo = "DuckDuckGo"
    case brave = "Brave Search"
    case google = "Google"
    case ecosia = "Ecosia"
    case kagi = "Kagi"
    case qwant = "Qwant"
    case searxng = "SearXNG"
    case custom = "Personnalisé"
    
    public var id: String { rawValue }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.from(string: raw)
    }
    
    public static func from(string: String) -> SearchEngineType {
        if let exact = SearchEngineType(rawValue: string) {
            return exact
        }
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "duckduckgo", "duck duck go", "ddg":
            return .duckDuckGo
        case "brave", "brave search":
            return .brave
        case "google":
            return .google
        case "ecosia":
            return .ecosia
        case "kagi":
            return .kagi
        case "qwant":
            return .qwant
        case "searxng", "searx":
            return .searxng
        case "personnalisé", "personnalise", "custom", "personalizado":
            return .custom
        default:
            return .duckDuckGo
        }
    }
    
    public var localizedName: String {
        switch self {
        case .custom:
            switch LocalizationManager.shared.currentLanguage {
            case .en: return "Custom"
            case .es: return "Personalizado"
            default: return "Personnalisé"
            }
        default:
            return rawValue
        }
    }
    
    public var homeURL: URL {
        switch self {
        case .duckDuckGo: return URL(string: "https://duckduckgo.com")!
        case .brave: return URL(string: "https://search.brave.com")!
        case .google: return URL(string: "https://www.google.com")!
        case .ecosia: return URL(string: "https://www.ecosia.org")!
        case .kagi: return URL(string: "https://kagi.com")!
        case .qwant: return URL(string: "https://www.qwant.com")!
        case .searxng: return URL(string: "https://searx.be")!
        case .custom: return URL(string: "https://duckduckgo.com")!
        }
    }
    
    public var queryFormat: String {
        switch self {
        case .duckDuckGo:
            return "https://duckduckgo.com/?q=%@"
        case .brave:
            return "https://search.brave.com/search?q=%@"
        case .google:
            return "https://www.google.com/search?q=%@"
        case .ecosia:
            return "https://www.ecosia.org/search?q=%@"
        case .kagi:
            return "https://kagi.com/search?q=%@"
        case .qwant:
            return "https://www.qwant.com/?q=%@"
        case .searxng:
            return "https://searx.be/search?q=%@"
        case .custom:
            return "%@"
        }
    }
    
    public var iconName: String {
        switch self {
        case .duckDuckGo: return "shield.fill"
        case .brave: return "flame.fill"
        case .google: return "globe"
        case .ecosia: return "leaf.fill"
        case .kagi: return "sparkle"
        case .qwant: return "magnifyingglass.circle.fill"
        case .searxng: return "server.rack"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    public var iconURL: URL? {
        switch self {
        case .duckDuckGo:
            return URL(string: "https://icons.duckduckgo.com/ip3/duckduckgo.com.ico")
        case .brave:
            return URL(string: "https://icons.duckduckgo.com/ip3/search.brave.com.ico")
        case .google:
            return URL(string: "https://www.google.com/favicon.ico")
        case .ecosia:
            return URL(string: "https://icons.duckduckgo.com/ip3/ecosia.org.ico")
        case .kagi:
            return URL(string: "https://icons.duckduckgo.com/ip3/kagi.com.ico")
        case .qwant:
            return URL(string: "https://icons.duckduckgo.com/ip3/qwant.com.ico")
        case .searxng:
            return URL(string: "https://icons.duckduckgo.com/ip3/searx.space.ico")
        case .custom:
            return nil
        }
    }
}

public struct SearchEngineConfig: Codable, Equatable {
    public var selectedType: SearchEngineType
    public var customURLTemplate: String
    
    public init(
        selectedType: SearchEngineType = .duckDuckGo,
        customURLTemplate: String = "https://duckduckgo.com/?q=%@"
    ) {
        self.selectedType = selectedType
        self.customURLTemplate = customURLTemplate
    }
    
    enum CodingKeys: String, CodingKey {
        case selectedType
        case customURLTemplate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedType = (try? container.decode(SearchEngineType.self, forKey: .selectedType)) ?? .duckDuckGo
        self.customURLTemplate = (try? container.decode(String.self, forKey: .customURLTemplate)) ?? "https://duckduckgo.com/?q=%@"
    }
    
    public func url(for query: String) -> URL {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If query looks like a valid direct URL with scheme
        if let directURL = URL(string: trimmed), directURL.scheme != nil, directURL.host != nil {
            return directURL
        }
        
        // If query looks like domain (e.g. "github.com" or "news.ycombinator.com")
        if !trimmed.contains(" ") && (trimmed.contains(".com") || trimmed.contains(".org") || trimmed.contains(".net") || trimmed.contains(".io") || trimmed.contains(".fr") || trimmed.contains(".app") || trimmed.contains(".dev")) {
            if let webURL = URL(string: "https://\(trimmed)") {
                return webURL
            }
        }
        
        // Otherwise encode search query
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let template = selectedType == .custom ? (customURLTemplate.isEmpty ? SearchEngineType.duckDuckGo.queryFormat : customURLTemplate) : selectedType.queryFormat
        
        let urlString: String
        if template.contains("%@") {
            urlString = String(format: template, encoded)
        } else if template.contains("%s") {
            urlString = template.replacingOccurrences(of: "%s", with: encoded)
        } else {
            urlString = "\(template)\(encoded)"
        }
        
        return URL(string: urlString) ?? URL(string: "https://duckduckgo.com/?q=\(encoded)")!
    }
}
// MARK: - SearchEngineManager

public final class SearchEngineManager: ObservableObject {
    public static let shared = SearchEngineManager()
    
    public static let appGroupId = "group.app.zen-browser.companion"
    
    private let configKey = "zen_search_engine_config"
    private let typeKey = "zen_selected_search_engine"
    private let customURLKey = "zen_custom_search_engine_url"
    private let legacyTypeKeys = ["selected_search_engine", "search_engine", "default_search_engine", "searchEngine"]
    
    private var allSuites: [UserDefaults] {
        var suites: [UserDefaults] = []
        if TabManager.isAppGroupAvailable,
           let group = UserDefaults(suiteName: Self.appGroupId) {
            suites.append(group)
        }
        suites.append(UserDefaults.standard)
        return suites
    }
    
    @Published public var config: SearchEngineConfig {
        didSet {
            save()
        }
    }
    
    public init() {
        self.config = Self.loadPersistedConfig()
        // Ensure settings are mirrored and persisted across all containers immediately
        self.save()
    }
    
    private static func loadPersistedConfig() -> SearchEngineConfig {
        let configKey = "zen_search_engine_config"
        let typeKey = "zen_selected_search_engine"
        let customURLKey = "zen_custom_search_engine_url"
        let legacyTypeKeys = ["selected_search_engine", "search_engine", "default_search_engine", "searchEngine"]
        
        var suites: [UserDefaults] = []
        if TabManager.isAppGroupAvailable,
           let group = UserDefaults(suiteName: "group.app.zen-browser.companion") {
            suites.append(group)
        }
        suites.append(UserDefaults.standard)
        
        let decoder = JSONDecoder()
        
        // 1. Try decoding JSON config from highest priority suite down
        for suite in suites {
            if let data = suite.data(forKey: configKey),
               let saved = try? decoder.decode(SearchEngineConfig.self, from: data) {
                return saved
            }
        }
        
        // 2. Try raw string representations in case JSON was lost during update or schema migration
        for suite in suites {
            if let rawString = suite.string(forKey: typeKey), !rawString.isEmpty {
                let type = SearchEngineType.from(string: rawString)
                let customURL = suite.string(forKey: customURLKey) ?? ""
                return SearchEngineConfig(
                    selectedType: type,
                    customURLTemplate: customURL.isEmpty ? type.queryFormat : customURL
                )
            }
            
            for key in legacyTypeKeys {
                if let rawString = suite.string(forKey: key), !rawString.isEmpty {
                    let type = SearchEngineType.from(string: rawString)
                    let customURL = suite.string(forKey: customURLKey) ?? ""
                    return SearchEngineConfig(
                        selectedType: type,
                        customURLTemplate: customURL.isEmpty ? type.queryFormat : customURL
                    )
                }
            }
        }
        
        return SearchEngineConfig()
    }
    
    public func save() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(config)
        let typeRaw = config.selectedType.rawValue
        let customURL = config.customURLTemplate
        
        for suite in allSuites {
            if let data = data {
                suite.set(data, forKey: configKey)
            }
            suite.set(typeRaw, forKey: typeKey)
            suite.set(customURL, forKey: customURLKey)
            suite.synchronize()
        }
    }
}


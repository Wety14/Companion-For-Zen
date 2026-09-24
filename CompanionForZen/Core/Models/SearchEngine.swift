import Foundation

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

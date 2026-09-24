import Foundation
import Combine

/// Service to fetch real-time search engine suggestions as user types in the search bar.
public final class SearchSuggestionService: ObservableObject {
    public static let shared = SearchSuggestionService()
    
    @Published public var suggestions: [String] = []
    @Published public var isLoading: Bool = false
    
    private var currentTask: URLSessionDataTask?
    
    public init() {}
    
    /// Fetches live search suggestions for a given query and search engine.
    public func fetchSuggestions(for query: String, engine: SearchEngineType = .duckDuckGo) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                self.suggestions = []
                self.isLoading = false
            }
            return
        }
        
        currentTask?.cancel()
        
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        
        // Suggestion URL depending on search engine (using OpenSearch standard JSON format)
        let urlString: String
        switch engine {
        case .google:
            urlString = "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encoded)"
        case .brave:
            urlString = "https://search.brave.com/api/suggest?q=\(encoded)"
        case .ecosia:
            urlString = "https://ac.ecosia.org/autocomplete?q=\(encoded)&type=list"
        case .qwant:
            urlString = "https://api.qwant.com/v3/suggest?q=\(encoded)&client=opensearch"
        default:
            urlString = "https://duckduckgo.com/ac/?q=\(encoded)&type=list"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        isLoading = true
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, error == nil, let data = data else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            var results: [String] = []
            
            // 1. Try standard OpenSearch format: [ query, [ "suggestion 1", "suggestion 2", ... ] ]
            if let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
               json.count > 1,
               let list = json[1] as? [String] {
                results = list
            }
            // 2. Try DuckDuckGo / Brave dictionary format: [ { "phrase": "..." } ]
            else if let listDict = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                results = listDict.compactMap { dict in
                    (dict["phrase"] as? String) ?? (dict["query"] as? String)
                }
            }
            
            DispatchQueue.main.async {
                self.suggestions = results
                self.isLoading = false
            }
        }
        currentTask?.resume()
    }
    
    public func clear() {
        currentTask?.cancel()
        suggestions = []
        isLoading = false
    }
}

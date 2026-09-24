import Foundation

/// History recording and searching service.
public final class HistoryService: ObservableObject {
    public static let shared = HistoryService()
    
    @Published public var historyEntries: [HistoryEntry] = []
    
    private let historyKey = "companion_zen_history"
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            self.historyEntries = saved
        }
    }
    
    public func recordVisit(url: URL, title: String) {
        guard url.scheme == "http" || url.scheme == "https" else { return }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty ? (url.host ?? url.absoluteString) : trimmedTitle
        
        // If the most recent visit is the same URL within 60s, update it instead of cluttering
        if let first = historyEntries.first, first.url == url, abs(first.visitedAt.timeIntervalSinceNow) < 60 {
            historyEntries[0].title = resolvedTitle
            historyEntries[0].visitedAt = Date()
            historyEntries[0].visitCount += 1
            save()
            return
        }
        
        let newEntry = HistoryEntry(url: url, title: resolvedTitle)
        historyEntries.insert(newEntry, at: 0)
        
        // Cap history at 1500 items
        if historyEntries.count > 1500 {
            historyEntries = Array(historyEntries.prefix(1500))
        }
        save()
    }
    
    public func deleteEntry(_ entry: HistoryEntry) {
        historyEntries.removeAll(where: { $0.id == entry.id })
        save()
    }
    
    public func clearAll() {
        historyEntries.removeAll()
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(historyEntries) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}

/// Bookmarks management service.
public final class BookmarkService: ObservableObject {
    public static let shared = BookmarkService()
    
    @Published public var bookmarks: [Bookmark] = []
    
    private let bookmarksKey = "companion_zen_bookmarks"
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let saved = try? JSONDecoder().decode([Bookmark].self, from: data) {
            self.bookmarks = saved
        } else {
            // Default sample bookmarks
            self.bookmarks = [
                Bookmark(title: "Zen Browser", url: URL(string: "https://zen-browser.app")!),
                Bookmark(title: "GitHub - Zen Browser", url: URL(string: "https://github.com/zen-browser")!),
                Bookmark(title: "DuckDuckGo", url: URL(string: "https://duckduckgo.com")!)
            ]
            save()
        }
    }
    
    public func isBookmarked(url: URL) -> Bool {
        bookmarks.contains(where: { $0.url == url })
    }
    
    public func toggleBookmark(url: URL, title: String) {
        if let idx = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: idx)
        } else {
            let item = Bookmark(title: title.isEmpty ? (url.host ?? url.absoluteString) : title, url: url)
            bookmarks.insert(item, at: 0)
        }
        save()
    }
    
    public func deleteBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll(where: { $0.id == bookmark.id })
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
}

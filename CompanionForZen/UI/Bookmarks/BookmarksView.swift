import SwiftUI

/// Bookmarks manager list view.
public struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var bookmarkService = BookmarkService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    @State private var searchText: String = ""
    public var onSelectURL: (URL) -> Void
    
    public var body: some View {
        List {
                ForEach(filteredBookmarks) { bookmark in
                    Button(action: {
                        onSelectURL(bookmark.url)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(themeManager.accentColor)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bookmark.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(bookmark.url.host ?? bookmark.url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            bookmarkService.deleteBookmark(bookmark)
                        } label: {
                            Label(String(localized: "delete_tab", bundle: .main), systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: String(localized: "search_bookmark_prompt", bundle: .main))
            .navigationTitle(String(localized: "bookmarks", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filteredBookmarks: [Bookmark] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return bookmarkService.bookmarks
        }
        return bookmarkService.bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }
}

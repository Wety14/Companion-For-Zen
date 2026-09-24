import SwiftUI

/// Search & URL entry overlay, auto-focusing keyboard and offering:
/// - Clean interface: History displayed ONLY when search field is empty (max 4 items).
/// - 4 live browser search suggestions fetched as user types.
/// - Designed to fit inside the 2/3 bottom bandeau alongside the keyboard.
public struct SearchOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var suggestionService = SearchSuggestionService.shared
    
    @State private var queryText: String = ""
    @FocusState private var isFieldFocused: Bool
    
    public var currentURL: URL?
    public var isNewTab: Bool
    public var searchConfig: SearchEngineConfig
    public var onSelectURL: (URL) -> Void
    public var onDismiss: (() -> Void)?
    
    public init(
        currentURL: URL? = nil,
        isNewTab: Bool = true,
        searchConfig: SearchEngineConfig = SearchEngineConfig(),
        onSelectURL: @escaping (URL) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.isNewTab = isNewTab
        self.searchConfig = searchConfig
        self.onSelectURL = onSelectURL
        self.onDismiss = onDismiss
    }
    
    private func dismissOverlay() {
        isFieldFocused = false
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator Handle
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)
            
            // Search Text Field Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)
                
                TextField(tr("search_or_enter_address"), text: $queryText)
                    .focused($isFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .tint(themeManager.accentColor)
                    .onSubmit {
                        submitSearch(for: queryText)
                    }
                
                if !queryText.isEmpty {
                    Button(action: {
                        queryText = ""
                        suggestionService.clear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Content: 4 Suggestions or History
            let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            VStack(spacing: 0) {
                if trimmedQuery.isEmpty {
                    // Empty search: Display up to 4 recent history items
                    let entries = Array(historyService.historyEntries.prefix(4))
                    if !entries.isEmpty {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            Button(action: {
                                onSelectURL(entry.url)
                                dismissOverlay()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title.isEmpty ? entry.url.host ?? entry.url.absoluteString : entry.title)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text(entry.url.host ?? entry.url.absoluteString)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if index < entries.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                } else {
                    // When typing: Direct domain shortcut if applicable
                    if isPotentialDomain(trimmedQuery) {
                        Button(action: {
                            let url = searchConfig.url(for: trimmedQuery)
                            onSelectURL(url)
                            dismissOverlay()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                
                                Text("Accéder à :")
                                    .foregroundColor(.secondary)
                                
                                Text(trimmedQuery)
                                    .bold()
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 48)
                    }
                    
                    // Display exactly up to 4 live search suggestions
                    let topSuggestions = Array(suggestionService.suggestions.prefix(4))
                    ForEach(Array(topSuggestions.enumerated()), id: \.element) { index, suggestion in
                        HStack(spacing: 0) {
                            Button(action: {
                                submitSearch(for: suggestion)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    
                                    highlightedText(suggestion: suggestion, query: trimmedQuery)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            // Button to insert suggestion into search bar
                            Button(action: {
                                queryText = suggestion
                            }) {
                                Image(systemName: "arrow.up.backward")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if index < topSuggestions.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            
            Spacer(minLength: 0)
        }
        .onAppear {
            if !isNewTab, let url = currentURL, url.scheme != "about" {
                queryText = url.absoluteString
            } else {
                queryText = ""
            }
            suggestionService.clear()
            isFieldFocused = true
        }
        .onChange(of: queryText) { _, newQuery in
            let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                suggestionService.clear()
            } else {
                suggestionService.fetchSuggestions(for: trimmed, engine: searchConfig.selectedType)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    private func submitSearch(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let targetURL = searchConfig.url(for: trimmed)
        onSelectURL(targetURL)
        dismissOverlay()
    }
    
    private func isPotentialDomain(_ text: String) -> Bool {
        if text.contains(" ") { return false }
        let commonTLDs = [".com", ".org", ".net", ".io", ".fr", ".app", ".dev", ".de", ".co", ".ai", ".me", ".xyz"]
        return commonTLDs.contains { text.lowercased().hasSuffix($0) || text.lowercased().contains("\($0)/") }
    }
    
    @ViewBuilder
    private func highlightedText(suggestion: String, query: String) -> some View {
        if let range = suggestion.range(of: query, options: .caseInsensitive) {
            let prefix = String(suggestion[..<range.lowerBound])
            let match = String(suggestion[range])
            let suffix = String(suggestion[range.upperBound...])
            
            HStack(spacing: 0) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                Text(match)
                    .font(.body.bold())
                    .foregroundColor(themeManager.accentColor)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        } else {
            Text(suggestion)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

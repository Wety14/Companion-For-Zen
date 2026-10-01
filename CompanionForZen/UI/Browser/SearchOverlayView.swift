import SwiftUI

/// Search & URL entry overlay, auto-focusing keyboard and offering:
/// - Clean interface: History displayed ONLY when search field is empty (max 4 items).
/// - Incognito / Private Browsing mode toggle with eyeglasses / eyeglasses.slash animation.
/// - 4 live browser search suggestions fetched as user types.
/// - Designed to fit inside the 2/3 bottom bandeau alongside the keyboard.
public struct SearchOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var suggestionService = SearchSuggestionService.shared
    
    @State private var queryText: String = ""
    @State private var isPrivateMode: Bool = false
    @FocusState private var isFieldFocused: Bool
    
    public var currentURL: URL?
    public var isNewTab: Bool
    public var searchConfig: SearchEngineConfig
    public var onSelectURL: (URL, Bool) -> Void
    public var onDismiss: (() -> Void)?
    
    public init(
        currentURL: URL? = nil,
        isNewTab: Bool = true,
        isPrivate: Bool = false,
        searchConfig: SearchEngineConfig = SearchEngineManager.shared.config,
        onSelectURL: @escaping (URL, Bool) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.isNewTab = isNewTab
        self._isPrivateMode = State(initialValue: isPrivate)
        let initialQuery: String
        if let url = currentURL, url.absoluteString != "about:blank" && url != TabManager.zenWebsiteURL {
            initialQuery = url.absoluteString
        } else {
            initialQuery = ""
        }
        self._queryText = State(initialValue: initialQuery)
        self.searchConfig = searchConfig
        self.onSelectURL = onSelectURL
        self.onDismiss = onDismiss
    }
    
    public init(
        currentURL: URL? = nil,
        isNewTab: Bool = true,
        isPrivate: Bool = false,
        searchConfig: SearchEngineConfig = SearchEngineManager.shared.config,
        onSelectURL: @escaping (URL) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            currentURL: currentURL,
            isNewTab: isNewTab,
            isPrivate: isPrivate,
            searchConfig: searchConfig,
            onSelectURL: { url, _ in onSelectURL(url) },
            onDismiss: onDismiss
        )
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
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isPrivateMode ? .purple : themeManager.accentColor)
                    
                    TextField(
                        isPrivateMode ? String(localized: "search_private_prompt", bundle: .main) : String(localized: "search_or_enter_address", bundle: .main),
                        text: $queryText
                    )
                    .focused($isFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .tint(isPrivateMode ? .purple : themeManager.accentColor)
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
                        .buttonStyle(.plain)
                    }
                    
                    // Incognito / Private Browsing Toggle Button at the far right
                    Button(action: {
                        Haptics.medium()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isPrivateMode.toggle()
                        }
                    }) {
                        Image(systemName: isPrivateMode ? "eyeglasses.slash" : "eyeglasses")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isPrivateMode ? .purple : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isPrivateMode ? Color.purple.opacity(0.18) : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPrivateMode ? String(localized: "disable_private_browsing", bundle: .main) : String(localized: "private_browsing_desc", bundle: .main))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlass(
                    cornerRadius: 16,
                    strokeColor: isPrivateMode ? Color.purple.opacity(0.35) : Color.white.opacity(0.18)
                )
                
                Button(String(localized: "cancel", bundle: .main)) {
                    Haptics.light()
                    dismissOverlay()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Content: Private Notice, Suggestions or History
            let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                if trimmedQuery.isEmpty {
                    if isPrivateMode {
                        VStack(spacing: 12) {
                            Image(systemName: "eyeglasses.slash")
                                .font(.system(size: 38))
                                .foregroundColor(.purple)
                                .padding(.top, 20)
                            
                            Text(String(localized: "private_browsing_title", bundle: .main))
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                            
                            Text(String(localized: "private_browsing_desc", bundle: .main))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Empty search: Display up to 4 recent history items
                        let entries = Array(historyService.historyEntries.prefix(4))
                        if !entries.isEmpty {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                Button(action: {
                                    onSelectURL(entry.url, false)
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
                    }
                } else {
                    // When typing: Direct domain shortcut if applicable
                    if isPotentialDomain(trimmedQuery) {
                        Button(action: {
                            let url = SearchEngineManager.shared.config.url(for: trimmedQuery)
                            onSelectURL(url, isPrivateMode)
                            dismissOverlay()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                
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
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if !isNewTab, let url = currentURL, url.scheme != "about" {
                queryText = url.absoluteString
            } else {
                queryText = ""
            }
            suggestionService.clear()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isFieldFocused = true
            }
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
        let rawURL = SearchEngineManager.shared.config.url(for: trimmed)
        let targetURL = AdBlockService.shared.cleanTrackingParameters(from: rawURL)
        onSelectURL(targetURL, isPrivateMode)
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
                    .foregroundColor(isPrivateMode ? .purple : themeManager.accentColor)
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

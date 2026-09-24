import SwiftUI

/// Action sheet / Modal offering quick access to Web Tools, Zen Shield stats,
/// Reader Mode, Page Zoom, Translation, Desktop Mode, and unified navigation into
/// Downloads, History, Bookmarks, Firefox Sync, and Settings with a back button.
public struct WebToolsOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adBlockService = AdBlockService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var bookmarkService = BookmarkService.shared
    @ObservedObject var syncService = FirefoxSyncService.shared
    @ObservedObject var translationService = TranslationService.shared
    
    public var currentURL: URL?
    public var pageTitle: String
    
    @Binding var pageZoom: Double
    @Binding var isDesktopMode: Bool
    
    public var onToggleReader: () -> Void
    public var onTranslate: () -> Void
    public var onSelectURL: (URL) -> Void
    public var onShare: () -> Void
    public var onReload: (() -> Void)?
    
    public init(
        currentURL: URL? = nil,
        pageTitle: String = "",
        pageZoom: Binding<Double>,
        isDesktopMode: Binding<Bool>,
        onToggleReader: @escaping () -> Void,
        onTranslate: @escaping () -> Void,
        onSelectURL: @escaping (URL) -> Void,
        onShare: @escaping () -> Void,
        onReload: (() -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.pageTitle = pageTitle
        self._pageZoom = pageZoom
        self._isDesktopMode = isDesktopMode
        self.onToggleReader = onToggleReader
        self.onTranslate = onTranslate
        self.onSelectURL = onSelectURL
        self.onShare = onShare
        self.onReload = onReload
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Shield Card Button: Toggles Zen Protection specifically for the current domain
                    let currentDomain = adBlockService.domain(for: currentURL) ?? currentURL?.host ?? "ce site"
                    let isProtected = adBlockService.isProtectionEnabled(for: currentURL)
                    
                    Button {
                        Haptics.medium()
                        adBlockService.toggleProtection(for: currentURL)
                        dismiss()
                        onReload?()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(isProtected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: isProtected ? "checkmark.shield.fill" : "xmark.shield.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(isProtected ? .green : .red)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(isProtected ? "Protection Zen active" : "Protection Zen désactivée")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Text(isProtected
                                     ? "\(currentDomain) • Appuyez pour désactiver sur ce site"
                                     : "\(currentDomain) • Désactivée définitivement sur ce site")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(16)
                        .liquidGlass(
                            cornerRadius: 18,
                            strokeColor: isProtected ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Web Navigation Tools Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Outils Web")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // Reader Mode Button
                            ToolCardButton(
                                icon: "doc.plaintext.fill",
                                title: tr("reader_mode"),
                                subtitle: "Lecture zen",
                                color: .orange
                            ) {
                                dismiss()
                                onToggleReader()
                            }
                            
                            // Translation Button
                            ToolCardButton(
                                icon: "translate",
                                title: translationService.isPageTranslated ? tr("show_original") : tr("translate_page"),
                                color: translationService.isPageTranslated ? .indigo : .blue
                            ) {
                                dismiss()
                                onTranslate()
                            }
                            
                            // Desktop Mode Button
                            ToolCardButton(
                                icon: isDesktopMode ? "iphone" : "desktopcomputer",
                                title: isDesktopMode ? tr("mobile_mode") : tr("desktop_mode"),
                                subtitle: isDesktopMode ? "Actif" : "Inactif",
                                color: isDesktopMode ? themeManager.accentColor : .purple
                            ) {
                                Haptics.light()
                                isDesktopMode.toggle()
                            }
                            
                            // Bookmark Button
                            ToolCardButton(
                                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                                title: isBookmarked ? "Dans les favoris" : tr("add_bookmark"),
                                subtitle: isBookmarked ? "Enregistré" : "Sauvegarder",
                                color: .yellow
                            ) {
                                Haptics.light()
                                if let url = currentURL {
                                    bookmarkService.toggleBookmark(url: url, title: pageTitle)
                                }
                            }
                        }
                    }
                    
                    // Page Zoom Control
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(tr("page_zoom"))
                                .font(.headline)
                            Spacer()
                            Text("\(Int(pageZoom * 100))%")
                                .font(.system(.body, design: .monospaced, weight: .bold))
                                .foregroundColor(themeManager.accentColor)
                        }
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                if pageZoom > 0.5 {
                                    Haptics.light()
                                    pageZoom = max(0.5, pageZoom - 0.1)
                                }
                            }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            
                            Slider(value: $pageZoom, in: 0.5...2.0, step: 0.05)
                                .tint(themeManager.accentColor)
                            
                            Button(action: {
                                if pageZoom < 2.0 {
                                    Haptics.light()
                                    pageZoom = min(2.0, pageZoom + 0.1)
                                }
                            }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            
                            Button("100%") {
                                Haptics.light()
                                pageZoom = 1.0
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 18)
                    
                    // Quick Navigation Links (Pushes inside the same sheet with back button!)
                    VStack(spacing: 0) {
                        NavigationLink {
                            DownloadsView()
                        } label: {
                            QuickActionRowContent(icon: "arrow.down.circle.fill", title: tr("downloads"), color: .cyan)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            HistoryView { targetURL in
                                dismiss()
                                onSelectURL(targetURL)
                            }
                        } label: {
                            QuickActionRowContent(icon: "clock.fill", title: tr("history"), color: .indigo)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            BookmarksView { targetURL in
                                dismiss()
                                onSelectURL(targetURL)
                            }
                        } label: {
                            QuickActionRowContent(icon: "bookmark.circle.fill", title: tr("bookmarks"), color: .yellow)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            FirefoxSyncView { targetURL in
                                dismiss()
                                onSelectURL(targetURL)
                            }
                        } label: {
                            QuickActionRowContent(icon: "arrow.triangle.2.circlepath.circle.fill", title: tr("firefox_sync"), color: .orange)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            QuickActionRowContent(icon: "gearshape.fill", title: tr("settings"), color: .gray)
                        }
                    }
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
            }
            .navigationTitle("Zen Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Haptics.light()
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Haptics.light()
                        onShare()
                    }) {
                        ZStack {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 32, height: 32)
                                .shadow(color: themeManager.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .tint(themeManager.accentColor)
                }
            }
        }
    }
    
    private var isBookmarked: Bool {
        guard let url = currentURL else { return false }
        return bookmarkService.isBookmarked(url: url)
    }
}

private struct ToolCardButton: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionRowContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

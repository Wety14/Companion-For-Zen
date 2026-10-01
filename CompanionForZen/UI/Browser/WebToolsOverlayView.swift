import SwiftUI

/// Action sheet / Modal offering quick access to Web Tools, Zen Shield stats,
/// Page Zoom, Translation, Desktop Mode, and unified navigation into
/// Downloads, History, Firefox Sync, and Settings with a back button.
public struct WebToolsOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adBlockService = AdBlockService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var syncService = FirefoxSyncService.shared
    @ObservedObject var translationService = TranslationService.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    public var currentURL: URL?
    public var pageTitle: String
    
    @Binding var pageZoom: Double
    @Binding var isDesktopMode: Bool
    public var hasActiveTab: Bool
    
    public var onToggleReader: () -> Void
    public var onTranslate: () -> Void
    public var onSelectURL: (URL) -> Void
    public var onEditCurrentURL: (() -> Void)?
    public var onShare: () -> Void
    public var onReload: (() -> Void)?
    public var onFindInPage: (() -> Void)?
    
    @State private var showingPinSheet: Bool = false
    @State private var isCopied: Bool = false
    @State private var showingDisabledTranslationAlert: Bool = false
    @State private var navigateToSettingsWithHighlight: Bool = false
    
    public init(
        currentURL: URL? = nil,
        pageTitle: String = "",
        pageZoom: Binding<Double>,
        isDesktopMode: Binding<Bool>,
        hasActiveTab: Bool = true,
        onToggleReader: @escaping () -> Void = {},
        onTranslate: @escaping () -> Void,
        onSelectURL: @escaping (URL) -> Void,
        onEditCurrentURL: (() -> Void)? = nil,
        onShare: @escaping () -> Void,
        onReload: (() -> Void)? = nil,
        onFindInPage: (() -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.pageTitle = pageTitle
        self._pageZoom = pageZoom
        self._isDesktopMode = isDesktopMode
        self.hasActiveTab = hasActiveTab
        self.onToggleReader = onToggleReader
        self.onTranslate = onTranslate
        self.onSelectURL = onSelectURL
        self.onEditCurrentURL = onEditCurrentURL
        self.onShare = onShare
        self.onReload = onReload
        self.onFindInPage = onFindInPage
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if hasActiveTab {
                    // Shield Card Button: Toggles Zen Protection specifically for the current domain
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
                                    Text(isProtected ? String(localized: "shield_active", bundle: .main) : String(localized: "shield_disabled", bundle: .main))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Text(isProtected ? String(localized: "shield_disable_action", bundle: .main) : String(localized: "shield_enable_action", bundle: .main))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .liquidGlass(
                            cornerRadius: 18,
                            strokeColor: isProtected ? Color.green.opacity(0.3) : Color.red.opacity(0.3)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Web Navigation Tools Section (Translation & Desktop Mode)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(String(localized: "web_tools", bundle: .main))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // Translation Button
                            ToolCardButton(
                                icon: "translate",
                                title: translationService.isPageTranslated ? String(localized: "show_original", bundle: .main) : String(localized: "translate_page", bundle: .main),
                                color: translationService.isPageTranslated ? .indigo : .blue
                            ) {
                                if translationService.isPageTranslated {
                                    dismiss()
                                    onTranslate()
                                } else if translationService.provider == .none {
                                    showingDisabledTranslationAlert = true
                                } else {
                                    dismiss()
                                    onTranslate()
                                }
                            }
                            
                            // Desktop Mode Button
                            ToolCardButton(
                                icon: isDesktopMode ? "iphone" : "desktopcomputer",
                                title: isDesktopMode ? String(localized: "mobile_mode", bundle: .main) : String(localized: "desktop_mode", bundle: .main),
                                subtitle: isDesktopMode ? String(localized: "active_status", bundle: .main) : String(localized: "inactive_status", bundle: .main),
                                color: isDesktopMode ? themeManager.accentColor : .purple
                            ) {
                                Haptics.light()
                                isDesktopMode.toggle()
                            }
                            
                            // Find on Page Button
                            ToolCardButton(
                                icon: "doc.text.magnifyingglass",
                                title: String(localized: "find_in_page", bundle: .main),
                                color: .orange
                            ) {
                                dismiss()
                                onFindInPage?()
                            }
                        }
                    }
                    
                    // Page Zoom Control
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(localized: "page_zoom", bundle: .main))
                                .font(.headline)
                            Spacer()
                            Text(pageZoom, format: .percent.precision(.fractionLength(0)))
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
                            
                            Button(action: {
                                Haptics.light()
                                pageZoom = 1.0
                            }) {
                                Text(1.0, format: .percent.precision(.fractionLength(0)))
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
                    }
                    
                    // Quick Navigation Links (Pushes inside the same sheet with back button!)
                    VStack(spacing: 0) {
                        NavigationLink {
                            DownloadsView()
                        } label: {
                            QuickActionRowContent(icon: "arrow.down.circle.fill", title: String(localized: "downloads", bundle: .main), color: .cyan)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            HistoryView { targetURL in
                                dismiss()
                                onSelectURL(targetURL)
                            }
                        } label: {
                            QuickActionRowContent(icon: "clock.fill", title: String(localized: "history", bundle: .main), color: .indigo)
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        // Firefox Sync (Déverrouillé et pleinement fonctionnel)
                        NavigationLink {
                            FirefoxSyncView { targetURL in
                                dismiss()
                                onSelectURL(targetURL)
                            }
                        } label: {
                            QuickActionRowContent(
                                icon: "arrow.triangle.2.circlepath.circle.fill",
                                title: String(localized: "firefox_sync", bundle: .main),
                                color: .orange,
                                badge: FirefoxSyncService.shared.isConnected ? String(localized: "connected", bundle: .main) : nil,
                                isLocked: false
                            )
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            QuickActionRowContent(icon: "gearshape.fill", title: String(localized: "settings", bundle: .main), color: .gray)
                        }
                    }
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, locManager.locale)
            .navigationDestination(isPresented: $navigateToSettingsWithHighlight) {
                SettingsView(highlightTranslationSetting: true)
            }
            .alert(String(localized: "translation_disabled_title", bundle: .main), isPresented: $showingDisabledTranslationAlert) {
                Button(String(localized: "ok", bundle: .main), role: .cancel) { }
                Button(String(localized: "translation_open_settings", bundle: .main)) {
                    navigateToSettingsWithHighlight = true
                }
            }
            .toolbar {
                if hasActiveTab {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        // Pin button: opens pin view identical to share extension
                        Button {
                            Haptics.light()
                            showingPinSheet = true
                        } label: {
                            Image(systemName: "pin")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                        
                        // Copy current link button (stripped of trackers)
                        Button {
                            Haptics.success()
                            if let url = currentURL {
                                let cleanURL = adBlockService.cleanTrackingParameters(from: url)
                                UIPasteboard.general.string = cleanURL.absoluteString
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        isCopied = false
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isCopied ? .green : .primary)
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                }
                
                ToolbarItem(placement: .principal) {
                    // Prominently sized URL domain in center
                    if hasActiveTab {
                        Button {
                            Haptics.light()
                            dismiss()
                            onEditCurrentURL?()
                        } label: {
                            Text(shortDomain)
                                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("zen_browser")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if hasActiveTab {
                        Button(action: {
                            Haptics.medium()
                            onShare()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(themeManager.accentColor.gradient, in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showingPinSheet) {
                if let url = currentURL {
                    PinTabView(url: url, initialTitle: pageTitle)
                        .presentationDetents([.fraction(0.55), .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    private var shortDomain: String {
        guard let url = currentURL, let host = url.host, !host.isEmpty else {
            return "zen-browser.app"
        }
        var cleaned = host.lowercased()
        if cleaned.hasPrefix("www.") {
            cleaned = String(cleaned.dropFirst(4))
        }
        return cleaned
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
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickActionRowContent: View {
    let icon: String
    let title: String
    let color: Color
    var badge: String? = nil
    var isLocked: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.gradient, in: Capsule())
            }
            
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

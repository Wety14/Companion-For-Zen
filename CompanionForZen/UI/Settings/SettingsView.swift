import SwiftUI

/// Main Settings view for Companion for Zen.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var handoffService = HandoffService.shared
    @ObservedObject var adBlockService = AdBlockService.shared
    @ObservedObject var syncService = FirefoxSyncService.shared
    @State private var showingTranslationPrivacyAlert: Bool = false
    
    @AppStorage("auto_archive_policy") private var autoArchivePolicy: AutoArchivePolicy = .twentyFourHours
    @AppStorage("block_ads") private var blockAds: Bool = true
    @AppStorage("block_trackers") private var blockTrackers: Bool = true
    @AppStorage("block_cookies") private var blockCookies: Bool = true
    public var highlightTranslationSetting: Bool = false
    @ObservedObject var translationService = TranslationService.shared
    @State private var isTranslationHighlighted: Bool = false
    
    @AppStorage("desktop_by_default") private var desktopByDefault: Bool = false
    @AppStorage("ai_auto_rename_pinned_tabs") private var aiAutoRenamePinnedTabs: Bool = true
    
    public init(highlightTranslationSetting: Bool = false) {
        self.highlightTranslationSetting = highlightTranslationSetting
    }
    
    @ObservedObject private var searchEngineManager = SearchEngineManager.shared
    
    public var body: some View {
        List {
                // Navigateur par défaut iOS
                Section {
                    Button(action: openDefaultBrowserSettings) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                            }
                            
                            Text(String(localized: "set_default_browser", bundle: .main))
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text(String(localized: "default_browser_footer", bundle: .main))
                }
                
                // Search Engine
                Section(String(localized: "search_engine", bundle: .main)) {
                    NavigationLink {
                        SearchEnginePickerView(searchConfig: $searchEngineManager.config)
                    } label: {
                        HStack(spacing: 12) {
                            SearchEngineLogoView(engine: searchEngineManager.config.selectedType, size: 24)
                            Text(String(localized: "search_engine", bundle: .main))
                            Spacer()
                            Text(searchEngineManager.config.selectedType.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Appearance & Theme
                Section(String(localized: "appearance", bundle: .main)) {
                    Picker(String(localized: "theme_mode", bundle: .main), selection: $themeManager.themeMode) {
                        Text(String(localized: "theme_automatic", bundle: .main)).tag(AppThemeMode.automatic)
                        Text(String(localized: "theme_light", bundle: .main)).tag(AppThemeMode.light)
                        Text(String(localized: "theme_dark", bundle: .main)).tag(AppThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    NavigationLink {
                        IconPickerView()
                    } label: {
                        HStack {
                            ZenLogoView(size: 24, showBackground: true, backgroundColor: themeManager.accentColor)
                            Text(String(localized: "app_icon", bundle: .main))
                            Spacer()
                            Text(String(localized: "customize", bundle: .main))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Synchronization & Zen Desktop Pairing
                Section(String(localized: "sync", bundle: .main)) {
                    NavigationLink {
                        FirefoxSyncView()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.orange)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(String(localized: "firefox_sync", bundle: .main))
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if syncService.isConnected {
                                Text(syncService.userEmail ?? String(localized: "connected", bundle: .main))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text(String(localized: "not_connected", bundle: .main))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Tabs & Auto-Archiving (Arc-like)
                Section(
                    header: Text(String(localized: "tabs_management", bundle: .main)),
                    footer: Text(String(localized: "ai_auto_rename_pinned_tabs_footer", bundle: .main))
                ) {
                    Picker(String(localized: "auto_archive_delay", bundle: .main), selection: $autoArchivePolicy) {
                        ForEach(AutoArchivePolicy.allCases) { policy in
                            Text(policy.localizedTitle).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: autoArchivePolicy) { _, newValue in
                        tabManager.performAutoArchiveCheck(policy: newValue)
                    }
                    
                    Toggle(String(localized: "ai_auto_rename_pinned_tabs", bundle: .main), isOn: $aiAutoRenamePinnedTabs)
                        .tint(themeManager.accentColor)
                    
                    NavigationLink {
                        AirTrafficControlView()
                    } label: {
                        HStack {
                            Image(systemName: "airplane")
                                .foregroundColor(themeManager.accentColor)
                            Text(String(localized: "air_traffic_control", bundle: .main))
                            Spacer()
                            Text(AirTrafficControlService.shared.rules.isEmpty ? String(localized: "default_rule_option", bundle: .main) : String(format: String(localized: "rules_count_format", bundle: .main), AirTrafficControlService.shared.rules.count))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        ArchivedTabsView()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundColor(.secondary)
                            Text(String(localized: "archived_tabs", bundle: .main))
                            Spacer()
                            Text("\(tabManager.archivedTabs.count)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Content Blocker (Zen Shield)
                Section(String(localized: "content_blocking", bundle: .main)) {
                    Toggle(String(localized: "block_ads", bundle: .main), isOn: $blockAds)
                        .tint(themeManager.accentColor)
                    Toggle(String(localized: "block_trackers", bundle: .main), isOn: $blockTrackers)
                        .tint(themeManager.accentColor)
                    Toggle(String(localized: "block_cookie_banners", bundle: .main), isOn: $blockCookies)
                        .tint(themeManager.accentColor)
                    Toggle(String(localized: "strip_url_trackers", bundle: .main), isOn: $adBlockService.stripTrackingParameters)
                        .tint(themeManager.accentColor)
                }
                
                // Language
                Section(String(localized: "language", bundle: .main)) {
                    Picker(String(localized: "language", bundle: .main), selection: $locManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Web Experience
                Section(String(localized: "navigation_section", bundle: .main)) {
                    Toggle(String(localized: "always_request_desktop", bundle: .main), isOn: $desktopByDefault)
                        .tint(themeManager.accentColor)
                }
                
                // Translation
                Section {
                    Picker(String(localized: "translation_settings_toggle", bundle: .main), selection: $translationService.provider) {
                        ForEach(TranslationProvider.allCases) { provider in
                            Text(provider.localizedTitle).tag(provider)
                        }
                    }
                    .tint(themeManager.accentColor)
                } header: {
                    Text(String(localized: "translation_settings_section", bundle: .main))
                }
                .listRowBackground(isTranslationHighlighted ? Color.gray.opacity(0.35) : nil)
                .id("translation_settings_section_id")
                
                // Continuity & Handoff
                Section(header: Text(String(localized: "handoff_title", bundle: .main))) {
                    Toggle(String(localized: "handoff_title", bundle: .main), isOn: $handoffService.isHandoffEnabled)
                        .tint(themeManager.accentColor)
                }
                
                // About
                Section(String(localized: "about_zen", bundle: .main)) {
                    HStack(spacing: 14) {
                        ZenLogoView(size: 40, showBackground: true, backgroundColor: themeManager.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zen Browser")
                                .font(.headline)
                            Text("Version 1.0 (Build 2026)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Link(destination: URL(string: "https://zen-browser.app")!) {
                        HStack {
                            Text(String(localized: "zen_official_website", bundle: .main))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/zen-browser")!) {
                        HStack {
                            Text(String(localized: "zen_github", bundle: .main))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.locale, locManager.locale)
            .navigationTitle(String(localized: "settings", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if highlightTranslationSetting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isTranslationHighlighted = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                isTranslationHighlighted = false
                            }
                        }
                    }
                }
            }
            .alert(String(localized: "translation_settings_section", bundle: .main), isPresented: $showingTranslationPrivacyAlert) {
                Button(String(localized: "ok", bundle: .main), role: .cancel) {}
            } message: {
                Text(String(localized: "translation_settings_footer", bundle: .main))
            }
    }
    
    private func openDefaultBrowserSettings() {
        Haptics.light()
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

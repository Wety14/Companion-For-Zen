import SwiftUI

/// Main Settings view for Companion for Zen.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var handoffService = HandoffService.shared
    
    @AppStorage("auto_archive_policy") private var autoArchivePolicy: AutoArchivePolicy = .twentyFourHours
    @AppStorage("block_ads") private var blockAds: Bool = true
    @AppStorage("block_trackers") private var blockTrackers: Bool = true
    @AppStorage("block_cookies") private var blockCookies: Bool = true
    @AppStorage("desktop_by_default") private var desktopByDefault: Bool = false
    @AppStorage("translation_always_allow") private var alwaysAllowTranslation: Bool = false
    
    @State private var searchConfig = SearchEngineConfig()
    
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
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tr("set_default_browser"))
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text(tr("default_browser_subtitle"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text(tr("default_browser_footer"))
                }
                
                // Search Engine
                Section(tr("search_engine")) {
                    NavigationLink {
                        SearchEnginePickerView(searchConfig: $searchConfig)
                    } label: {
                        HStack(spacing: 12) {
                            SearchEngineLogoView(engine: searchConfig.selectedType, size: 24)
                            Text(tr("search_engine"))
                            Spacer()
                            Text(searchConfig.selectedType.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Appearance & Theme
                Section(tr("appearance")) {
                    Picker(tr("theme_mode"), selection: $themeManager.themeMode) {
                        Text(tr("theme_automatic")).tag(AppThemeMode.automatic)
                        Text(tr("theme_light")).tag(AppThemeMode.light)
                        Text(tr("theme_dark")).tag(AppThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    NavigationLink {
                        IconPickerView()
                    } label: {
                        HStack {
                            ZenLogoView(size: 24, showBackground: true, backgroundColor: themeManager.accentColor)
                            Text(tr("app_icon"))
                            Spacer()
                            Text("Personnaliser")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Tabs & Auto-Archiving (Arc-like)
                Section(header: Text("Gestion des onglets"), footer: Text("Les onglets inactifs non épinglés sont archivés sans aucune IA pour préserver la mémoire et l'autonomie.")) {
                    Picker(tr("auto_archive_delay"), selection: $autoArchivePolicy) {
                        ForEach(AutoArchivePolicy.allCases) { policy in
                            Text(policy.rawValue).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: autoArchivePolicy) { _, newValue in
                        tabManager.performAutoArchiveCheck(policy: newValue)
                    }
                    
                    NavigationLink {
                        ArchivedTabsView()
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                                .foregroundColor(.secondary)
                            Text(tr("archived_tabs"))
                            Spacer()
                            Text("\(tabManager.archivedTabs.count)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Content Blocker (Zen Shield)
                Section(tr("content_blocking")) {
                    Toggle(tr("block_ads"), isOn: $blockAds)
                        .tint(themeManager.accentColor)
                    Toggle(tr("block_trackers"), isOn: $blockTrackers)
                        .tint(themeManager.accentColor)
                    Toggle(tr("block_cookie_banners"), isOn: $blockCookies)
                        .tint(themeManager.accentColor)
                }
                
                // Language
                Section(tr("language")) {
                    Picker(tr("language"), selection: $locManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Web Experience
                Section("Navigation") {
                    Toggle("Toujours demander la version ordinateur", isOn: $desktopByDefault)
                        .tint(themeManager.accentColor)
                }
                
                // Translation
                Section(header: Text(tr("translation_settings_section")), footer: Text(tr("translation_settings_footer"))) {
                    Toggle(tr("translation_settings_toggle"), isOn: $alwaysAllowTranslation)
                        .tint(themeManager.accentColor)
                        .onChange(of: alwaysAllowTranslation) { _, newValue in
                            TranslationService.shared.alwaysAllowTranslation = newValue
                        }
                }
                
                // Continuity & Handoff
                Section(header: Text(tr("handoff_title")), footer: Text(tr("handoff_desc"))) {
                    Toggle("Activer Handoff avec Zen macOS", isOn: $handoffService.isHandoffEnabled)
                        .tint(themeManager.accentColor)
                }
                
                // About
                Section(tr("about_zen")) {
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
                            Text("Site officiel Zen Browser")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/zen-browser")!) {
                        HStack {
                            Text("Zen Browser sur GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(tr("settings"))
            .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openDefaultBrowserSettings() {
        Haptics.light()
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

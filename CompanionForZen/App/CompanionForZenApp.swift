import SwiftUI

@main
struct CompanionForZenApp: App {
    @StateObject private var tabManager = TabManager.shared
    @StateObject private var themeManager = ZenThemeManager.shared
    @StateObject private var locManager = LocalizationManager.shared
    @StateObject private var adBlockService = AdBlockService.shared
    @StateObject private var syncService = FirefoxSyncService.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        ZenThemeManager.shared.updateKeyboardAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            BrowserContainerView()
                .environmentObject(locManager)
                .environment(\.locale, locManager.locale)
                .tint(themeManager.accentColor)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    themeManager.updateSystemColorScheme(systemColorScheme)
                }
        }
        .onChange(of: systemColorScheme) { _, newScheme in
            themeManager.updateSystemColorScheme(newScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                tabManager.reloadFromDisk()
            } else if newPhase == .background {
                tabManager.saveToDisk()
            }
        }
    }
}

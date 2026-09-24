import SwiftUI

@main
struct CompanionForZenApp: App {
    @StateObject private var tabManager = TabManager.shared
    @StateObject private var themeManager = ZenThemeManager.shared
    @StateObject private var locManager = LocalizationManager.shared
    @StateObject private var adBlockService = AdBlockService.shared
    @StateObject private var syncService = FirefoxSyncService.shared
    
    init() {
        ZenThemeManager.shared.updateKeyboardAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            BrowserContainerView()
                .tint(themeManager.accentColor)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

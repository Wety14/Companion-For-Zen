import SwiftUI
import WebKit
#if canImport(Translation)
import Translation
#endif

/// Main Browser Container hosting the Web View, Bottom Omnibar, Gesture Engine, and overlays.
public struct BrowserContainerView: View {
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var readerService = ReaderModeService.shared
    @ObservedObject var translationService = TranslationService.shared
    @ObservedObject var downloadService = DownloadService.shared
    @ObservedObject var handoffService = HandoffService.shared
    
    // Web View State
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var estimatedProgress: Double = 0.0
    @State private var isLoading: Bool = false
    @State private var currentURL: URL?
    @State private var pageTitle: String = ""
    @State private var pageZoom: Double = 1.0
    @State private var isDesktopMode: Bool = false
    
    // Command Triggers
    @State private var reloadTrigger: Bool = false
    @State private var goBackTrigger: Bool = false
    @State private var goForwardTrigger: Bool = false
    @State private var loadURLTrigger: URL?
    
    // Sheet Presentations
    @State private var showingSearchOverlay: Bool = false
    @State private var showingTabDrawer: Bool = false
    @State private var showingWebTools: Bool = false
    @State private var isPageColorLight: Bool = false
    @State private var searchDragOffset: CGFloat = 0
    @State private var translationConfig: Any?
    @State private var showingTranslationDialog: Bool = false
    
    // Gestures State
    @GestureState private var dragOffset: CGFloat = 0
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background Theme Color
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            // Intelligent status bar protection: subtle translucent backdrop matching the top area
            VStack {
                LinearGradient(
                    colors: [
                        (isPageColorLight ? Color.white : Color.black).opacity(0.85),
                        (isPageColorLight ? Color.white : Color.black).opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 52)
                .ignoresSafeArea(edges: .top)
                Spacer()
            }
            .allowsHitTesting(false)
            .zIndex(15)
            
            // Full Screen Web View Layer: Eliminates black bottom bar and maximizes visible content
            ZStack {
                if let activeTab = tabManager.activeTab {
                    WebViewContainer(
                        tab: activeTab,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        estimatedProgress: $estimatedProgress,
                        isLoading: $isLoading,
                        currentURL: $currentURL,
                        pageTitle: $pageTitle,
                        isPageColorLight: $isPageColorLight,
                        reloadTrigger: reloadTrigger,
                        goBackTrigger: goBackTrigger,
                        goForwardTrigger: goForwardTrigger,
                        loadURLTrigger: loadURLTrigger,
                        pageZoom: pageZoom,
                        isDesktopMode: isDesktopMode
                    )
                    .id(activeTab.id) // Reload view when tab changes
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(!showingSearchOverlay)
                } else {
                    VStack(spacing: 16) {
                        ZenLogoView(size: 64, showBackground: true, backgroundColor: themeManager.accentColor)
                        Text("Aucun onglet actif")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Ouvrir un onglet") {
                            tabManager.openNewTab()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(themeManager.accentColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Top banners overlay (Handoff Continuity)
            VStack(spacing: 0) {
                // Incoming Handoff Continuity Banner from macOS
                if handoffService.showIncomingHandoffBanner, let url = handoffService.incomingHandoffURL {
                    HStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeManager.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("handoff_banner_title"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(handoffService.incomingHandoffTitle ?? url.host ?? url.absoluteString)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(tr("handoff_open")) {
                            loadURLTrigger = url
                            handoffService.dismissIncomingBanner()
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.accentColor)
                        .clipShape(Capsule())
                        
                        Button {
                            handoffService.dismissIncomingBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .liquidGlass(cornerRadius: 16, strokeColor: themeManager.accentColor.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            
            // Floating Bottom Omnibar overlay (Floats on top of web content with no solid black bar)
            BottomOmnibarView(
                currentURL: currentURL,
                pageTitle: pageTitle,
                isLoading: isLoading,
                progress: estimatedProgress,
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                onBack: {
                    goBackTrigger.toggle()
                },
                onForward: {
                    goForwardTrigger.toggle()
                },
                onReload: {
                    reloadTrigger.toggle()
                },
                onOpenSearch: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showingSearchOverlay = true
                    }
                },
                onOpenTabDrawer: {
                    showingTabDrawer = true
                },
                onOpenTools: {
                    showingWebTools = true
                },
                onOpenSendTab: {
                    sharePage()
                },
                onShare: {
                    sharePage()
                }
            )
            // Gesture on Omnibar: Swipe up to reveal Tab Drawer
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height < -30 {
                            Haptics.medium()
                            showingTabDrawer = true
                        } else if value.translation.width > 50 {
                            switchToPreviousTab()
                        } else if value.translation.width < -50 {
                            switchToNextTab()
                        }
                    }
            )
            .padding(.bottom, 0)
            .zIndex(5)
            
            // Fullscreen Reader Mode View (when active)
            if readerService.isReaderActive {
                ReaderModeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
            
            // 2/3 Height Search & Tab Opening Bandeau (Stays strictly at 2/3 even with keyboard active)
            if showingSearchOverlay {
                Color.black.opacity(max(0, 0.4 * (1.0 - Double(searchDragOffset) / 400.0)))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showingSearchOverlay = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(20)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    SearchOverlayView(
                        currentURL: nil,
                        isNewTab: true,
                        searchConfig: SearchEngineConfig(),
                        onSelectURL: { targetURL in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                showingSearchOverlay = false
                            }
                            tabManager.openNewTab(url: targetURL)
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                showingSearchOverlay = false
                            }
                        }
                    )
                    .frame(height: UIScreen.main.bounds.height * (2.0 / 3.0))
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: -5)
                    .offset(y: max(0, searchDragOffset))
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    searchDragOffset = value.translation.height
                                    if value.translation.height > 15 {
                                        UIApplication.shared.sendAction(
                                            #selector(UIResponder.resignFirstResponder),
                                            to: nil,
                                            from: nil,
                                            for: nil
                                        )
                                    }
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 90 || value.predictedEndTranslation.height > 200 {
                                    Haptics.light()
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        searchDragOffset = UIScreen.main.bounds.height
                                        showingSearchOverlay = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        searchDragOffset = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        searchDragOffset = 0
                                    }
                                }
                            }
                    )
                }
                .ignoresSafeArea(.all)
                .transition(.move(edge: .bottom))
                .zIndex(25)
            }
            
            // Translation System Permission Dialog
            if showingTranslationDialog {
                TranslationPermissionDialog(
                    onAllowOnce: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingTranslationDialog = false
                        }
                        triggerTranslation()
                    },
                    onAlwaysAllow: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingTranslationDialog = false
                        }
                        translationService.alwaysAllowTranslation = true
                        triggerTranslation()
                    },
                    onDeny: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingTranslationDialog = false
                        }
                    }
                )
                .ignoresSafeArea(.all)
                .zIndex(100)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingTabDrawer) {
            TabDrawerView(onOpenSearch: {
                showingTabDrawer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showingSearchOverlay = true
                    }
                }
            })
        }
        .sheet(isPresented: $showingWebTools) {
            WebToolsOverlayView(
                currentURL: currentURL,
                pageTitle: pageTitle,
                pageZoom: $pageZoom,
                isDesktopMode: $isDesktopMode,
                onToggleReader: {
                    toggleReader()
                },
                onTranslate: {
                    handleTranslationToggle()
                },
                onSelectURL: { targetURL in
                    loadURLTrigger = targetURL
                },
                onShare: { sharePage() },
                onReload: { reloadTrigger.toggle() }
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: currentURL) { _, newURL in
            handoffService.broadcastTab(
                url: newURL,
                title: pageTitle,
                spaceName: tabManager.activeSpace.name
            )
        }
        .onChange(of: pageTitle) { _, newTitle in
            handoffService.broadcastTab(
                url: currentURL,
                title: newTitle,
                spaceName: tabManager.activeSpace.name
            )
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let incoming = handoffService.handleIncomingUserActivity(userActivity) {
                loadURLTrigger = incoming
            }
        }
        .onContinueUserActivity("app.zenbrowser.companion.browsing") { userActivity in
            if let incoming = handoffService.handleIncomingUserActivity(userActivity) {
                loadURLTrigger = incoming
            }
        }
        .onOpenURL { incomingURL in
            if incomingURL.scheme == "http" || incomingURL.scheme == "https" {
                tabManager.openNewTab(url: incomingURL)
                loadURLTrigger = incomingURL
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .applyWebTranslation(configuration: $translationConfig, webViewProvider: {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else { return nil }
            return findWKWebView(in: window)
        }, translationService: translationService)
    }
    
    // MARK: - Navigation helpers
    
    private func switchToPreviousTab() {
        let activeTabs = tabManager.activeTabs(for: tabManager.activeSpaceId)
        guard let curId = tabManager.activeTabId, let idx = activeTabs.firstIndex(where: { $0.id == curId }) else { return }
        if idx > 0 {
            Haptics.light()
            tabManager.selectTab(activeTabs[idx - 1])
        }
    }
    
    private func switchToNextTab() {
        let activeTabs = tabManager.activeTabs(for: tabManager.activeSpaceId)
        guard let curId = tabManager.activeTabId, let idx = activeTabs.firstIndex(where: { $0.id == curId }) else { return }
        if idx < activeTabs.count - 1 {
            Haptics.light()
            tabManager.selectTab(activeTabs[idx + 1])
        }
    }
    
    private func toggleReader() {
        if readerService.isReaderActive {
            readerService.exitReader()
        } else {
            // Find active webview in window hierarchy
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let webView = findWKWebView(in: window) else { return }
            readerService.extractArticle(from: webView) { _ in }
        }
    }
    
    private func handleTranslationToggle() {
        if translationService.isPageTranslated {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
                  let webView = findWKWebView(in: window) else { return }
            Haptics.light()
            Task {
                await translationService.restoreOriginal(webView: webView)
            }
        } else {
            if translationService.alwaysAllowTranslation {
                triggerTranslation()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showingTranslationDialog = true
                }
            }
        }
    }
    
    private func triggerTranslation() {
        if #available(iOS 18.0, *) {
            #if canImport(Translation)
            Haptics.light()
            if var config = translationConfig as? TranslationSession.Configuration {
                config.invalidate()
                translationConfig = config
            } else {
                translationConfig = TranslationSession.Configuration()
            }
            #endif
        }
    }
    
    private func sharePage() {
        guard let url = currentURL else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else { return }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        var items: [Any] = [url]
        if !pageTitle.isEmpty {
            items.append(pageTitle)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.maxY - 80, width: 0, height: 0)
            popover.permittedArrowDirections = [.down, .any]
        }
        
        topVC.present(activityVC, animated: true)
    }
    
    private func findWKWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for subview in view.subviews {
            if let found = findWKWebView(in: subview) {
                return found
            }
        }
        return nil
    }
}

#if canImport(Translation)
@available(iOS 18.0, *)
private struct WebTranslationModifier: ViewModifier {
    @Binding var configuration: TranslationSession.Configuration?
    let webViewProvider: () -> WKWebView?
    let translationService: TranslationService
    
    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                guard let webView = webViewProvider() else { return }
                await translationService.translateWebPage(using: session, webView: webView)
            }
    }
}
#endif

private extension View {
    @ViewBuilder
    func applyWebTranslation(
        configuration: Binding<Any?>,
        webViewProvider: @escaping () -> WKWebView?,
        translationService: TranslationService
    ) -> some View {
        if #available(iOS 18.0, *) {
            #if canImport(Translation)
            let configBinding = Binding<TranslationSession.Configuration?>(
                get: { configuration.wrappedValue as? TranslationSession.Configuration },
                set: { configuration.wrappedValue = $0 }
            )
            self.modifier(WebTranslationModifier(
                configuration: configBinding,
                webViewProvider: webViewProvider,
                translationService: translationService
            ))
            #else
            self
            #endif
        } else {
            self
        }
    }
}
// MARK: - Translation Permission Dialog

private struct TranslationPermissionDialog: View {
    let onAllowOnce: () -> Void
    let onAlwaysAllow: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDeny()
                }
            
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 58, height: 58)
                    
                    Image(systemName: "translate")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
                
                // Titles
                VStack(spacing: 8) {
                    Text(tr("translation_dialog_title"))
                        .font(.headline.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(tr("translation_dialog_message"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Action Buttons
                VStack(spacing: 10) {
                    // Toujours autoriser (Highlight en bleu)
                    Button(action: {
                        Haptics.light()
                        onAlwaysAllow()
                    }) {
                        Text(tr("translation_always_allow"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    
                    // Autoriser
                    Button(action: {
                        Haptics.light()
                        onAllowOnce()
                    }) {
                        Text(tr("translation_allow_once"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    
                    // Refuser
                    Button(action: {
                        Haptics.light()
                        onDeny()
                    }) {
                        Text(tr("translation_deny"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 25, x: 0, y: 10)
            )
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
}


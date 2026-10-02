import SwiftUI
import QuickLook
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
    @ObservedObject var searchEngineManager = SearchEngineManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var adBlockService = AdBlockService.shared
    
    // Web View State
    @State private var isFastScrolling: Bool = false
    @State private var isKeyboardVisible: Bool = false
    @State private var quickLookURL: URL? = nil
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
    // Sheet Presentations
    @State private var showingSearchOverlay: Bool = false
    @State private var showingTabDrawer: Bool = false
    @State private var isTabsOverview: Bool = false
    @State private var showingWebTools: Bool = false
    @State private var isPageColorLight: Bool = false
    @State private var translationConfig: Any?
    @State private var showingChooseTranslationDialog: Bool = false
    @State private var isEditingCurrentTabURL: Bool = false
    
    // Find In Page State
    @State private var isFindInPageVisible: Bool = false
    @State private var findInPageText: String = ""
    @State private var findInPageCurrentIndex: Int = 0
    @State private var findInPageTotalMatches: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    
    // Gestures State (Progressive finger-following swipe between open tabs)
    @State private var tabDragOffset: CGFloat = 0
    @State private var isSwipingTabs: Bool = false
    
    private var openTabs: [Tab] {
        tabManager.openTabs
    }
    
    private var currentTabIndex: Int {
        guard let activeTab = tabManager.activeTab else { return 0 }
        return openTabs.firstIndex(where: { $0.id == activeTab.id }) ?? 0
    }
    
    private var adjacentTab: Tab? {
        guard openTabs.count > 1 else { return nil }
        if tabDragOffset > 0 && currentTabIndex > 0 {
            return openTabs[currentTabIndex - 1]
        } else if tabDragOffset < 0 && currentTabIndex < openTabs.count - 1 {
            return openTabs[currentTabIndex + 1]
        }
        return nil
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background Theme Color
            (!isTabsOverview && tabManager.activeTab != nil && isPageColorLight ? Color.white : themeManager.backgroundColor)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: isPageColorLight)
            
            // Full Screen Web View Layer: Eliminates black bottom bar and maximizes visible content
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let screenHeight = geo.size.height
                let cardWidth = max(min(screenWidth * 0.72, 310), 120)
                let cardScale = cardWidth / screenWidth
                
                let isLandscape = screenWidth > screenHeight
                let safeLeading = (!isTabsOverview && isLandscape) ? geo.safeAreaInsets.leading : 0
                let safeTrailing = (!isTabsOverview && isLandscape) ? geo.safeAreaInsets.trailing : 0
                
                ZStack(alignment: .topLeading) {
                    if let activeTab = tabManager.activeTab, !isTabsOverview {
                        WebViewContainer(
                            tab: activeTab,
                            canGoBack: $canGoBack,
                            canGoForward: $canGoForward,
                            estimatedProgress: $estimatedProgress,
                            isLoading: $isLoading,
                            currentURL: $currentURL,
                            pageTitle: $pageTitle,
                            isPageColorLight: $isPageColorLight,
                            isFastScrolling: $isFastScrolling,
                            reloadTrigger: reloadTrigger,
                            goBackTrigger: goBackTrigger,
                            goForwardTrigger: goForwardTrigger,
                            loadURLTrigger: loadURLTrigger,
                            pageZoom: pageZoom,
                            isDesktopMode: isDesktopMode
                        )
                        .id(activeTab.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.leading, safeLeading)
                        .padding(.trailing, safeTrailing)
                        .offset(x: isTabsOverview ? 0 : tabDragOffset)
                        .ignoresSafeArea(.all)
                        .scaleEffect(isTabsOverview ? cardScale : 1.0)
                        .clipShape(RoundedRectangle(cornerRadius: isTabsOverview ? 24 : 0, style: .continuous))
                        .shadow(
                            color: Color.black.opacity(isTabsOverview ? 0.35 : 0),
                            radius: isTabsOverview ? 16 : 0,
                            x: 0,
                            y: isTabsOverview ? 8 : 0
                        )
                        .opacity(isTabsOverview ? 0 : 1)
                        .allowsHitTesting(!isTabsOverview)
                    } else {
                        // Interactive empty state with draggable Zen logo, ripples, and color cycle
                        EmptyTabsZenView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.leading, safeLeading)
                            .padding(.trailing, safeTrailing)
                            .ignoresSafeArea(.all)
                    }
                    
                    // Progressive adjacent tab preview sliding synchronously with finger
                    if let adj = adjacentTab, isSwipingTabs, !isTabsOverview {
                        let adjX = tabDragOffset > 0 ? (-screenWidth + tabDragOffset) : (screenWidth + tabDragOffset)
                        TabSwipePreviewView(tab: adj)
                            .frame(width: screenWidth)
                            .offset(x: adjX)
                            .padding(.leading, safeLeading)
                            .padding(.trailing, safeTrailing)
                            .ignoresSafeArea(.all)
                    }
                    
                    // Unified Tabs Switcher Overview
                    if isTabsOverview {
                        TabSwitcherView(
                            onDismiss: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    isTabsOverview = false
                                }
                            },
                            onSelectTab: { _ in
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    isTabsOverview = false
                                }
                            },
                            onOpenSpacesMenu: {
                                showingTabDrawer = true
                            },
                            onOpenSearch: {
                                isEditingCurrentTabURL = false
                                showingSearchOverlay = true
                            }
                        )
                        .frame(width: screenWidth, height: screenHeight)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.15)),
                            removal: .opacity.combined(with: .scale(scale: 1.15))
                        ))
                        .zIndex(10)
                    }
                }
            }
            .ignoresSafeArea(.all)
            
            // Bottom Omnibar (Floating modern browser bar, hidden when keyboard is active)
            if !isKeyboardVisible {
                BottomOmnibarView(
                    currentURL: currentURL,
                    pageTitle: pageTitle,
                    isLoading: isLoading,
                    progress: estimatedProgress,
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    isFastScrolling: isFastScrolling,
                    hasActiveTab: tabManager.activeTab != nil,
                    isTabsOverview: isTabsOverview,
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
                        isEditingCurrentTabURL = false
                        showingSearchOverlay = true
                    },
                    onOpenTabDrawer: {
                        showingTabDrawer = true
                    },
                    onOpenTabSwitcher: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            isTabsOverview = true
                        }
                    },
                    onOpenTools: {
                        showingWebTools = true
                    },
                    onOpenSendTab: {
                        sharePage()
                    },
                    onShare: {
                        sharePage()
                    },
                    onOpenFinishedDownload: { item in
                        if let fileURL = item.destinationFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                            quickLookURL = fileURL
                        }
                    }
                )
                .allowsHitTesting(!showingSearchOverlay)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard !isTabsOverview else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            if isSwipingTabs || abs(dx) > abs(dy) * 1.4 {
                                isSwipingTabs = true
                                if dx > 0 && currentTabIndex == 0 {
                                    tabDragOffset = dx * 0.25 // rubber banding at start
                                } else if dx < 0 && currentTabIndex >= openTabs.count - 1 {
                                    tabDragOffset = dx * 0.25 // rubber banding at end
                                } else {
                                    tabDragOffset = dx
                                }
                            }
                        }
                        .onEnded { value in
                            guard !isTabsOverview, isSwipingTabs else {
                                tabDragOffset = 0
                                return
                            }
                            handleHorizontalTabSwipeEnded(value: value, screenWidth: UIScreen.main.bounds.width)
                        }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .padding(.bottom, 0)
                .zIndex(25)
            }
            
            // Floating Find In Page Toolbar
            if isFindInPageVisible {
                findInPageFloatingBar
            }
            
            // Fullscreen Reader Mode View (when active)
            if readerService.isReaderActive {
                ReaderModeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
            

        }
        .sheet(isPresented: $showingTabDrawer) {
            TabDrawerView(
                onOpenSearch: {
                    showingTabDrawer = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isEditingCurrentTabURL = false
                        showingSearchOverlay = true
                    }
                },
                onSelectTab: {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        isTabsOverview = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingSearchOverlay) {
            SearchOverlayView(
                currentURL: isEditingCurrentTabURL ? currentURL : nil,
                isNewTab: !isEditingCurrentTabURL,
                isPrivate: tabManager.activeTab?.isPrivate ?? false,
                searchConfig: searchEngineManager.config,
                onSelectURL: { targetURL, isPrivate in
                    showingSearchOverlay = false
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        isTabsOverview = false
                    }
                    if isEditingCurrentTabURL {
                        tabManager.updateCurrentTabURL(url: targetURL)
                        loadURLTrigger = targetURL
                        isEditingCurrentTabURL = false
                    } else {
                        tabManager.openNewTab(url: targetURL, isPrivate: isPrivate)
                    }
                },
                onDismiss: {
                    showingSearchOverlay = false
                    isEditingCurrentTabURL = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
        .alert(
            String(localized: "download_permission_title", bundle: .main),
            isPresented: Binding(
                get: { downloadService.pendingDownload != nil },
                set: { if !$0 { downloadService.cancelPendingDownload() } }
            ),
            presenting: downloadService.pendingDownload
        ) { pending in
            Button(String(localized: "cancel", bundle: .main), role: .cancel) {
                downloadService.cancelPendingDownload()
            }
            Button(String(localized: "download_action", bundle: .main)) {
                downloadService.confirmPendingDownload()
            }
        } message: { pending in
            Text(String(format: String(localized: "download_permission_message", bundle: .main), pending.filename))
        }
        .sheet(isPresented: $showingWebTools) {
            WebToolsOverlayView(
                currentURL: currentURL,
                pageTitle: pageTitle,
                pageZoom: $pageZoom,
                isDesktopMode: $isDesktopMode,
                hasActiveTab: tabManager.activeTab != nil,
                onToggleReader: {
                    toggleReader()
                },
                onTranslate: {
                    handleTranslationToggle()
                },
                onSelectURL: { targetURL in
                    loadURLTrigger = targetURL
                },
                onEditCurrentURL: {
                    isEditingCurrentTabURL = true
                    showingSearchOverlay = true
                },
                onShare: { sharePage() },
                onReload: { reloadTrigger.toggle() },
                onFindInPage: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        presentFindInPage()
                    }
                }
            )
            .environmentObject(locManager)
            .environment(\.locale, locManager.locale)
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            String(localized: "translation_dialog_title", bundle: .main),
            isPresented: $showingChooseTranslationDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "translation_provider_system", bundle: .main)) {
                triggerSystemTranslation()
            }
            Button(String(localized: "translation_provider_google", bundle: .main)) {
                triggerGoogleTranslation()
            }
            Button(String(localized: "cancel", bundle: .main), role: .cancel) { }
        }
        .onChange(of: tabManager.openTabs.isEmpty) { _, isEmpty in
            if isEmpty {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isTabsOverview = false
                }
            }
        }
        .onChange(of: currentURL) { _, newURL in
            if isFindInPageVisible {
                closeFindInPage()
            }
            handoffService.broadcastTab(
                url: newURL,
                title: pageTitle,
                spaceName: tabManager.activeSpace.name,
                isPrivate: tabManager.activeTab?.isPrivate ?? false
            )
        }
        .onChange(of: pageTitle) { _, newTitle in
            handoffService.broadcastTab(
                url: currentURL,
                title: newTitle,
                spaceName: tabManager.activeSpace.name,
                isPrivate: tabManager.activeTab?.isPrivate ?? false
            )
        }
        .onChange(of: findInPageText) { _, newText in
            guard let webView = activeWKWebView() else { return }
            FindInPageController.shared.search(query: newText, in: webView) { index, count in
                findInPageCurrentIndex = index
                findInPageTotalMatches = count
            }
        }
        .onChange(of: tabManager.activeTabId) { _, _ in
            if isFindInPageVisible {
                closeFindInPage()
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let incoming = handoffService.handleIncomingUserActivity(userActivity) {
                loadURLTrigger = adBlockService.cleanTrackingParameters(from: incoming)
            }
        }
        .onContinueUserActivity(HandoffService.zenCompanionActivityType) { userActivity in
            if let incoming = handoffService.handleIncomingUserActivity(userActivity) {
                loadURLTrigger = adBlockService.cleanTrackingParameters(from: incoming)
            }
        }
        .onContinueUserActivity("app.zenbrowser.companion.browsing") { userActivity in
            if let incoming = handoffService.handleIncomingUserActivity(userActivity) {
                loadURLTrigger = adBlockService.cleanTrackingParameters(from: incoming)
            }
        }
        .onChange(of: tabManager.shouldOpenSearchOnEmptySpaceSwitch) { _, shouldOpen in
            if shouldOpen {
                tabManager.shouldOpenSearchOnEmptySpaceSwitch = false
                showingSearchOverlay = true
            }
        }
        .onOpenURL { incomingURL in
            if incomingURL.scheme == "http" || incomingURL.scheme == "https" {
                let cleanURL = adBlockService.cleanTrackingParameters(from: incomingURL)
                let targetSpaceId = AirTrafficControlService.shared.resolveTargetSpace(
                    for: cleanURL,
                    currentSpaces: tabManager.spaces,
                    lastActiveSpaceId: tabManager.activeSpaceId
                )
                tabManager.switchSpace(to: targetSpaceId)
                let newTab = tabManager.openNewTab(url: cleanURL, spaceId: targetSpaceId)
                tabManager.selectTab(newTab)
                loadURLTrigger = cleanURL
            }
        }
        .quickLookPreview($quickLookURL)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let height = frame?.height ?? 0
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
                keyboardHeight = height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
                keyboardHeight = 0
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(themeManager.colorScheme)
        .applyWebTranslation(configuration: $translationConfig, webViewProvider: {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else { return nil }
            return findWKWebView(in: window)
        }, translationService: translationService)
    }
    

    
    // MARK: - Navigation helpers
    
    private func switchToPreviousTab() {
        guard currentTabIndex > 0 else { return }
        Haptics.light()
        tabManager.selectTab(openTabs[currentTabIndex - 1])
    }
    
    private func switchToNextTab() {
        guard currentTabIndex < openTabs.count - 1 else { return }
        Haptics.light()
        tabManager.selectTab(openTabs[currentTabIndex + 1])
    }
    
    private func handleHorizontalTabSwipeEnded(value: DragGesture.Value, screenWidth: CGFloat) {
        let translation = value.translation.width
        let velocity = value.predictedEndTranslation.width - translation
        let threshold = screenWidth * 0.25
        
        let shouldSwitchLeft = (translation > threshold || velocity > 250) && currentTabIndex > 0
        let shouldSwitchRight = (translation < -threshold || velocity < -250) && currentTabIndex < openTabs.count - 1
        
        if shouldSwitchLeft {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                tabDragOffset = screenWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                switchToPreviousTab()
                tabDragOffset = 0
                isSwipingTabs = false
            }
        } else if shouldSwitchRight {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                tabDragOffset = -screenWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                switchToNextTab()
                tabDragOffset = 0
                isSwipingTabs = false
            }
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                tabDragOffset = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                isSwipingTabs = false
            }
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
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let webView = findWKWebView(in: window) else { return }
        
        if translationService.isPageTranslated {
            Haptics.light()
            Task {
                await translationService.restoreOriginal(webView: webView)
            }
        } else {
            switch translationService.provider {
            case .none:
                break
            case .askPerTab:
                showingChooseTranslationDialog = true
            case .system:
                triggerSystemTranslation()
            case .google:
                triggerGoogleTranslation(webView: webView)
            }
        }
    }
    
    private func triggerSystemTranslation() {
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
    
    private func triggerGoogleTranslation(webView: WKWebView? = nil) {
        guard let targetWebView = webView ?? activeWKWebView() else { return }
        Haptics.light()
        translationService.translateWithGoogle(webView: targetWebView, currentURL: currentURL)
    }
    
    private func activeWKWebView() -> WKWebView? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else { return nil }
        return findWKWebView(in: window)
    }
    
    private func presentFindInPage() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isFindInPageVisible = true
        }
    }
    
    private func closeFindInPage() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            isFindInPageVisible = false
        }
        findInPageText = ""
        findInPageCurrentIndex = 0
        findInPageTotalMatches = 0
        if let webView = activeWKWebView() {
            FindInPageController.shared.clear(in: webView)
        }
    }
    
    private func sharePage() {
        guard let rawURL = currentURL else { return }
        let url = adBlockService.cleanTrackingParameters(from: rawURL)
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
    
    // MARK: - Find In Page Floating Bar
    @ViewBuilder
    private var findInPageFloatingBar: some View {
        FindInPageView(
            searchText: $findInPageText,
            currentIndex: findInPageCurrentIndex,
            totalMatches: findInPageTotalMatches,
            onPrevious: {
                guard let webView = activeWKWebView() else { return }
                FindInPageController.shared.previous(in: webView) { index, count in
                    findInPageCurrentIndex = index
                    findInPageTotalMatches = count
                }
            },
            onNext: {
                guard let webView = activeWKWebView() else { return }
                FindInPageController.shared.next(in: webView) { index, count in
                    findInPageCurrentIndex = index
                    findInPageTotalMatches = count
                }
            },
            onClose: {
                closeFindInPage()
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, isKeyboardVisible ? (keyboardHeight + 8) : 84)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .zIndex(45)
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

// MARK: - Find In Page UI View
private struct FindInPageView: View {
    @Binding var searchText: String
    var currentIndex: Int
    var totalMatches: Int
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onClose: () -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Search Input Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField(String(localized: "find_in_page", bundle: .main), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        onNext()
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.07))
            .cornerRadius(10)
            
            // Match Counter (e.g. 1/4)
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(totalMatches > 0 ? "\(currentIndex)/\(totalMatches)" : "0/0")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(totalMatches > 0 ? .primary : .secondary)
                    .lineLimit(1)
            }
            
            // Navigation Arrows (Up / Down)
            HStack(spacing: 2) {
                Button(action: {
                    Haptics.light()
                    onPrevious()
                }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 32)
                        .contentShape(Rectangle())
                }
                .disabled(totalMatches <= 1)
                .opacity(totalMatches <= 1 ? 0.35 : 1.0)
                .buttonStyle(.plain)
                
                Button(action: {
                    Haptics.light()
                    onNext()
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 32)
                        .contentShape(Rectangle())
                }
                .disabled(totalMatches <= 1)
                .opacity(totalMatches <= 1 ? 0.35 : 1.0)
                .buttonStyle(.plain)
            }
            .foregroundColor(.primary)
            
            // Close Button
            Button(action: {
                Haptics.light()
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.09))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
    }
}

// MARK: - Find In Page JavaScript Controller
private final class FindInPageController {
    static let shared = FindInPageController()
    
    private let injectionScript = """
    if (!window.__zenFind) {
        window.__zenFind = {
            matches: [],
            currentIndex: -1,
            
            clear: function() {
                var marks = document.querySelectorAll('mark.zen-find-highlight');
                marks.forEach(function(m) {
                    var parent = m.parentNode;
                    if (parent) {
                        while (m.firstChild) {
                            parent.insertBefore(m.firstChild, m);
                        }
                        parent.removeChild(m);
                        parent.normalize();
                    }
                });
                this.matches = [];
                this.currentIndex = -1;
            },
            
            search: function(query) {
                this.clear();
                if (!query || query.trim().length === 0) {
                    return JSON.stringify({ count: 0, index: 0 });
                }
                
                var q = query.trim().toLowerCase();
                var walker = document.createTreeWalker(
                    document.body,
                    NodeFilter.SHOW_TEXT,
                    {
                        acceptNode: function(node) {
                            if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
                            var parentTag = node.parentElement ? node.parentElement.tagName.toLowerCase() : '';
                            if (['script', 'style', 'noscript', 'textarea', 'input', 'select', 'button'].indexOf(parentTag) !== -1) {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return NodeFilter.FILTER_ACCEPT;
                        }
                    },
                    false
                );
                
                var nodes = [];
                var n;
                while (n = walker.nextNode()) {
                    if (n.nodeValue.toLowerCase().indexOf(q) !== -1) {
                        nodes.push(n);
                    }
                }
                
                var self = this;
                var createdMarks = [];
                
                nodes.forEach(function(textNode) {
                    var parent = textNode.parentNode;
                    if (!parent) return;
                    var text = textNode.nodeValue;
                    var lowerText = text.toLowerCase();
                    var fragment = document.createDocumentFragment();
                    var lastIdx = 0;
                    var index = 0;
                    
                    while ((index = lowerText.indexOf(q, lastIdx)) !== -1) {
                        if (index > lastIdx) {
                            fragment.appendChild(document.createTextNode(text.substring(lastIdx, index)));
                        }
                        
                        var mark = document.createElement('mark');
                        mark.className = 'zen-find-highlight';
                        mark.style.backgroundColor = 'rgba(255, 235, 59, 0.55)';
                        mark.style.color = '#000000';
                        mark.style.borderRadius = '3px';
                        mark.style.padding = '1px 2px';
                        mark.style.margin = '0 1px';
                        mark.style.boxShadow = '0 0 0 1px rgba(0,0,0,0.1)';
                        mark.appendChild(document.createTextNode(text.substr(index, q.length)));
                        
                        fragment.appendChild(mark);
                        createdMarks.push(mark);
                        
                        lastIdx = index + q.length;
                    }
                    
                    if (lastIdx < text.length) {
                        fragment.appendChild(document.createTextNode(text.substring(lastIdx)));
                    }
                    
                    parent.replaceChild(fragment, textNode);
                });
                
                this.matches = createdMarks;
                if (this.matches.length > 0) {
                    this.currentIndex = 0;
                    this.updateActive();
                    return JSON.stringify({ count: this.matches.length, index: 1 });
                } else {
                    this.currentIndex = -1;
                    return JSON.stringify({ count: 0, index: 0 });
                }
            },
            
            updateActive: function() {
                if (this.matches.length === 0 || this.currentIndex < 0) return;
                var self = this;
                this.matches.forEach(function(m, i) {
                    if (i === self.currentIndex) {
                        m.style.backgroundColor = '#ff9800';
                        m.style.color = '#ffffff';
                        m.style.outline = '2px solid #e65100';
                        m.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    } else {
                        m.style.backgroundColor = 'rgba(255, 235, 59, 0.55)';
                        m.style.color = '#000000';
                        m.style.outline = 'none';
                    }
                });
            },
            
            next: function() {
                if (this.matches.length === 0) return JSON.stringify({ count: 0, index: 0 });
                this.currentIndex = (this.currentIndex + 1) % this.matches.length;
                this.updateActive();
                return JSON.stringify({ count: this.matches.length, index: this.currentIndex + 1 });
            },
            
            previous: function() {
                if (this.matches.length === 0) return JSON.stringify({ count: 0, index: 0 });
                this.currentIndex = (this.currentIndex - 1 + this.matches.length) % this.matches.length;
                this.updateActive();
                return JSON.stringify({ count: this.matches.length, index: this.currentIndex + 1 });
            }
        };
    }
    """
    
    func search(query: String, in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            clear(in: webView)
            completion(0, 0)
            return
        }
        
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let js = injectionScript + "\nwindow.__zenFind.search(decodeURIComponent('\(encoded)'));"
        
        webView.evaluateJavaScript(js) { result, _ in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let count = dict["count"] as? Int,
                  let index = dict["index"] as? Int else {
                completion(0, 0)
                return
            }
            completion(index, count)
        }
    }
    
    func next(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        let js = injectionScript + "\nwindow.__zenFind.next();"
        webView.evaluateJavaScript(js) { result, _ in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let count = dict["count"] as? Int,
                  let index = dict["index"] as? Int else {
                completion(0, 0)
                return
            }
            completion(index, count)
        }
    }
    
    func previous(in webView: WKWebView, completion: @escaping (Int, Int) -> Void) {
        let js = injectionScript + "\nwindow.__zenFind.previous();"
        webView.evaluateJavaScript(js) { result, _ in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let count = dict["count"] as? Int,
                  let index = dict["index"] as? Int else {
                completion(0, 0)
                return
            }
            completion(index, count)
        }
    }
    
    func clear(in webView: WKWebView) {
        let js = injectionScript + "\nwindow.__zenFind.clear();"
        webView.evaluateJavaScript(js, completionHandler: nil)
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


// MARK: - Tab Swipe Preview View
private struct TabSwipePreviewView: View {
    let tab: Tab
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            VStack(spacing: 16) {
                TabFaviconView(tab: tab, size: 44, fallbackColor: .primary)
                
                Text(tab.title.isEmpty ? tab.shortDomain : tab.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text(tab.shortDomain)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}


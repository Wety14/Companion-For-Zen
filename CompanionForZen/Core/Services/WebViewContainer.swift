import SwiftUI
import WebKit

/// UIViewRepresentable wrapping WKWebView with AdBlock, Zoom, Fast-Scroll detection, and Snapshot support.
public struct WebViewContainer: UIViewRepresentable {
    public let tab: Tab
    @ObservedObject var adBlockService = AdBlockService.shared
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var estimatedProgress: Double
    @Binding var isLoading: Bool
    @Binding var currentURL: URL?
    @Binding var pageTitle: String
    @Binding var isPageColorLight: Bool
    @Binding var isFastScrolling: Bool
    
    // Command triggers
    public var reloadTrigger: Bool
    public var goBackTrigger: Bool
    public var goForwardTrigger: Bool
    public var loadURLTrigger: URL?
    public var pageZoom: Double
    public var isDesktopMode: Bool
    
    public init(
        tab: Tab,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        estimatedProgress: Binding<Double>,
        isLoading: Binding<Bool>,
        currentURL: Binding<URL?>,
        pageTitle: Binding<String>,
        isPageColorLight: Binding<Bool> = .constant(true),
        isFastScrolling: Binding<Bool> = .constant(false),
        reloadTrigger: Bool = false,
        goBackTrigger: Bool = false,
        goForwardTrigger: Bool = false,
        loadURLTrigger: URL? = nil,
        pageZoom: Double = 1.0,
        isDesktopMode: Bool = false
    ) {
        self.tab = tab
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._estimatedProgress = estimatedProgress
        self._isLoading = isLoading
        self._currentURL = currentURL
        self._pageTitle = pageTitle
        self._isPageColorLight = isPageColorLight
        self._isFastScrolling = isFastScrolling
        self.reloadTrigger = reloadTrigger
        self.goBackTrigger = goBackTrigger
        self.goForwardTrigger = goForwardTrigger
        self.loadURLTrigger = loadURLTrigger
        self.pageZoom = pageZoom
        self.isDesktopMode = isDesktopMode
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Request desktop or mobile content mode
        configuration.defaultWebpagePreferences.preferredContentMode = isDesktopMode ? .desktop : .mobile
        
        // Private / Incognito browsing: use non-persistent website data store (no cookies/cache saved to disk)
        if tab.isPrivate {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        
        // Apply Ad, Tracker, and Cookie Banner blocking
        adBlockService.applyTo(configuration: configuration, url: tab.url)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 75, right: 0)
        webView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 75, right: 0)
        
        // Pull-to-refresh: Swiping down refreshes the current web page
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        context.coordinator.refreshControl = refreshControl
        
        // Set custom user agent for desktop mode if enabled
        if isDesktopMode {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        }
        
        context.coordinator.setupObservers(for: webView)
        context.coordinator.webView = webView
        
        // Initial load
        let request = URLRequest(url: tab.url)
        webView.load(request)
        
        return webView
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle triggers
        if let newURL = loadURLTrigger, context.coordinator.lastLoadedURLTrigger != newURL {
            context.coordinator.lastLoadedURLTrigger = newURL
            adBlockService.updateWebViewBlocking(webView: webView, for: newURL)
            webView.load(URLRequest(url: newURL))
        }
        
        if let lastReload = context.coordinator.lastReloadTrigger {
            if lastReload != reloadTrigger {
                context.coordinator.lastReloadTrigger = reloadTrigger
                adBlockService.updateWebViewBlocking(webView: webView, for: webView.url)
                webView.reload()
            }
        } else {
            context.coordinator.lastReloadTrigger = reloadTrigger
        }
        
        if let lastBack = context.coordinator.lastGoBackTrigger {
            if lastBack != goBackTrigger {
                context.coordinator.lastGoBackTrigger = goBackTrigger
                if webView.canGoBack {
                    webView.goBack()
                }
            }
        } else {
            context.coordinator.lastGoBackTrigger = goBackTrigger
        }
        
        if let lastForward = context.coordinator.lastGoForwardTrigger {
            if lastForward != goForwardTrigger {
                context.coordinator.lastGoForwardTrigger = goForwardTrigger
                if webView.canGoForward {
                    webView.goForward()
                }
            }
        } else {
            context.coordinator.lastGoForwardTrigger = goForwardTrigger
        }
        
        // Update page zoom
        if abs(webView.pageZoom - CGFloat(pageZoom)) > 0.05 {
            webView.pageZoom = CGFloat(pageZoom)
        }
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKDownloadDelegate {
        var parent: WebViewContainer
        weak var webView: WKWebView?
        weak var refreshControl: UIRefreshControl?
        var lastReloadTrigger: Bool? = nil
        var lastGoBackTrigger: Bool? = nil
        var lastGoForwardTrigger: Bool? = nil
        var lastLoadedURLTrigger: URL? = nil
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var themeColorObservation: NSKeyValueObservation?
        
        private var scrollIdleWorkItem: DispatchWorkItem?
        private var isCurrentlyFastScrolling = false
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSnapshotNotification),
                name: Notification.Name("CaptureCurrentTabSnapshot"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleSnapshotNotification() {
            captureSnapshot()
        }
        
        @objc func handleRefresh(_ sender: UIRefreshControl) {
            Haptics.light()
            webView?.reload()
        }
        
        func captureSnapshot() {
            guard let webView = self.webView, webView.bounds.width > 0, webView.bounds.height > 0 else { return }
            let config = WKSnapshotConfiguration()
            config.afterScreenUpdates = false
            let tabId = self.parent.tab.id
            webView.takeSnapshot(with: config) { image, error in
                if let img = image {
                    TabSnapshotManager.shared.saveSnapshot(img, for: tabId)
                }
            }
        }
        
        func setupObservers(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.estimatedProgress = wv.estimatedProgress
                }
            }
            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    let title = wv.title ?? ""
                    self?.parent.pageTitle = title
                    if let url = wv.url {
                        TabManager.shared.updateActiveTab(url: url, title: title)
                        if let isPrivate = self?.parent.tab.isPrivate, !isPrivate {
                            HistoryService.shared.recordVisit(url: url, title: title)
                        }
                    }
                }
            }
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.currentURL = wv.url
                }
            }
            canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = wv.canGoBack
                }
            }
            canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = wv.canGoForward
                }
            }
            loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.isLoading = wv.isLoading
                    if !wv.isLoading {
                        self?.refreshControl?.endRefreshing()
                    }
                }
            }
            if #available(iOS 15.0, *) {
                themeColorObservation = webView.observe(\.themeColor, options: [.new]) { [weak self] wv, _ in
                    self?.detectPageLightness(wv)
                }
            }
        }
        
        // MARK: - UIScrollViewDelegate (Fast-Scroll Detection - Permissive Downward Reduction)
        
        private var lastContentOffsetY: CGFloat = 0
        private var lastScrollTime: CFTimeInterval = 0
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            lastContentOffsetY = scrollView.contentOffset.y
            lastScrollTime = CACurrentMediaTime()
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentOffsetY = scrollView.contentOffset.y
            let now = CACurrentMediaTime()
            let dt = max(now - lastScrollTime, 0.001)
            let deltaY = currentOffsetY - lastContentOffsetY
            let realVelocityY = deltaY / CGFloat(dt) // positive when scrolling down
            
            lastScrollTime = now
            lastContentOffsetY = currentOffsetY
            
            // 1. At top of the webpage or scrolling upwards: restore full size
            if currentOffsetY <= 15 {
                endFastScroll()
                return
            }
            
            if deltaY < -6 {
                // Scrolling up -> restore omnibar immediately
                endFastScroll()
                return
            }
            
            // 2. Permissive detection for scrolling downwards:
            let panVelocityY = abs(scrollView.panGestureRecognizer.velocity(in: scrollView).y)
            let isMovingDownwards = deltaY > 1 && (
                panVelocityY > 120 ||
                realVelocityY > 120 ||
                (scrollView.isDragging && deltaY > 3) ||
                (scrollView.isDecelerating && deltaY > 5)
            )
            
            if isMovingDownwards {
                if !isCurrentlyFastScrolling {
                    isCurrentlyFastScrolling = true
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.isFastScrolling = true
                    }
                }
                
                scrollIdleWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.isCurrentlyFastScrolling else { return }
                    self.isCurrentlyFastScrolling = false
                    DispatchQueue.main.async {
                        self.parent.isFastScrolling = false
                    }
                }
                scrollIdleWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.40, execute: workItem)
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            scrollIdleWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.endFastScroll()
            }
            scrollIdleWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                scrollIdleWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    self?.endFastScroll()
                }
                scrollIdleWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
            }
        }
        
        private func endFastScroll() {
            scrollIdleWorkItem?.cancel()
            if isCurrentlyFastScrolling {
                isCurrentlyFastScrolling = false
                DispatchQueue.main.async { [weak self] in
                    self?.parent.isFastScrolling = false
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                TranslationService.shared.reset()
            }
            parent.adBlockService.updateWebViewBlocking(webView: webView, for: webView.url ?? self.parent.currentURL)
        }
        
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            detectPageLightness(webView)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.estimatedProgress = 1.0
                self.refreshControl?.endRefreshing()
            }
            detectPageLightness(webView)
            // Capture real content snapshot once page is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.captureSnapshot()
            }
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
            }
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            
            // Handle external schemes (e.g. mailto:, tel:, sms:, maps:) safely in main app process
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme != "http" && scheme != "https" && scheme != "about" && scheme != "blob" && scheme != "data" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            
            decisionHandler(.allow)
        }
        
        public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Automatically recover if WebContent process was terminated by system
            webView.reload()
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }
        
        public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        // MARK: - WKDownloadDelegate
        
        public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let targetURL = download.originalRequest?.url ?? response.url
            if let url = targetURL {
                DownloadService.shared.requestDownload(url: url, suggestedFilename: suggestedFilename)
            }
            completionHandler(nil)
        }
        
        func detectPageLightness(_ webView: WKWebView) {
            if #available(iOS 15.0, *), let themeColor = webView.themeColor {
                let isLight = themeColor.isLightColor
                DispatchQueue.main.async {
                    self.parent.isPageColorLight = isLight
                }
                return
            }
            
            if #available(iOS 15.0, *), let underColor = webView.underPageBackgroundColor, underColor != .clear {
                let isLight = underColor.isLightColor
                DispatchQueue.main.async {
                    self.parent.isPageColorLight = isLight
                }
                return
            }
        }
    }
}

fileprivate extension UIColor {
    var isLightColor: Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            if alpha < 0.1 { return true }
            let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
            return luminance > 0.5
        }
        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return white > 0.5
        }
        return true
    }
}

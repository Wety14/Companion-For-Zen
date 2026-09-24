import SwiftUI
import WebKit

/// UIViewRepresentable wrapping WKWebView with AdBlock, Zoom, and Desktop Site support.
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
        
        // Apply Ad, Tracker, and Cookie Banner blocking
        adBlockService.applyTo(configuration: configuration, url: tab.url)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
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
        if let newURL = loadURLTrigger, webView.url != newURL {
            adBlockService.updateWebViewBlocking(webView: webView, for: newURL)
            webView.load(URLRequest(url: newURL))
        }
        
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            adBlockService.updateWebViewBlocking(webView: webView, for: webView.url)
            webView.reload()
        }
        
        if context.coordinator.lastGoBackTrigger != goBackTrigger {
            context.coordinator.lastGoBackTrigger = goBackTrigger
            if webView.canGoBack {
                webView.goBack()
            }
        }
        
        if context.coordinator.lastGoForwardTrigger != goForwardTrigger {
            context.coordinator.lastGoForwardTrigger = goForwardTrigger
            if webView.canGoForward {
                webView.goForward()
            }
        }
        
        // Update page zoom
        if abs(webView.pageZoom - CGFloat(pageZoom)) > 0.05 {
            webView.pageZoom = CGFloat(pageZoom)
        }
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        var parent: WebViewContainer
        weak var webView: WKWebView?
        weak var refreshControl: UIRefreshControl?
        var lastReloadTrigger: Bool = false
        var lastGoBackTrigger: Bool = false
        var lastGoForwardTrigger: Bool = false
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var loadingObservation: NSKeyValueObservation?
        private var themeColorObservation: NSKeyValueObservation?
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        @objc func handleRefresh(_ sender: UIRefreshControl) {
            Haptics.light()
            webView?.reload()
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
                        HistoryService.shared.recordVisit(url: url, title: title)
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
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
            }
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
            }
        }
        
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Check if navigation action is a file download
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
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
            if let originalURL = download.originalRequest?.url {
                DownloadService.shared.startDownload(url: originalURL, suggestedFilename: suggestedFilename)
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
            
            let js = """
            (function() {
                var el = document.body;
                var bg = el ? window.getComputedStyle(el).backgroundColor : '';
                if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
                    var doc = document.documentElement;
                    bg = doc ? window.getComputedStyle(doc).backgroundColor : '';
                }
                return bg || '';
            })()
            """
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self = self else { return }
                let bgStr = (result as? String) ?? ""
                let isLight = self.isColorStringLight(bgStr)
                DispatchQueue.main.async {
                    self.parent.isPageColorLight = isLight
                }
            }
        }
        
        private func isColorStringLight(_ str: String) -> Bool {
            if str.isEmpty || str == "transparent" || str == "rgba(0, 0, 0, 0)" {
                return true
            }
            let nums = str.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Double($0) }
            if nums.count >= 3 {
                let r = nums[0] / 255.0
                let g = nums[1] / 255.0
                let b = nums[2] / 255.0
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                return luminance > 0.5
            }
            return true
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

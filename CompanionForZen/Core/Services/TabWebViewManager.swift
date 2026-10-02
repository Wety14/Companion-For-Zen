import Foundation
import WebKit

/// Central manager and cache for active WKWebView instances associated with open tabs.
/// Keeps pages rendered in memory so they can be previewed seamlessly in the Tab Switcher
/// and instantly restored when switching tabs, without saving any photos to disk.
public final class TabWebViewManager {
    public static let shared = TabWebViewManager()
    
    private var webViews: [UUID: WKWebView] = [:]
    
    private init() {}
    
    /// Retrieves an existing WKWebView or creates and initiates a new one for the specified tab.
    @MainActor
    public func webView(for tab: Tab) -> WKWebView {
        if let existing = webViews[tab.id] {
            return existing
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = tab.isDesktopMode ? .desktop : .mobile
        
        if tab.isPrivate {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        
        AdBlockService.shared.applyTo(configuration: configuration, url: tab.url)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        if tab.isDesktopMode {
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        }
        
        let request = URLRequest(url: tab.url)
        webView.load(request)
        
        webViews[tab.id] = webView
        return webView
    }
    
    /// Returns the existing WKWebView if one has already been created for this tab.
    @MainActor
    public func existingWebView(for tabId: UUID) -> WKWebView? {
        webViews[tabId]
    }
    
    /// Releases and removes the WKWebView when a tab is closed. Safe to call from any thread or actor.
    public func removeWebView(for tabId: UUID) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.performRemoveWebView(for: tabId)
            }
        } else {
            DispatchQueue.main.async {
                self.performRemoveWebView(for: tabId)
            }
        }
    }
    
    @MainActor
    private func performRemoveWebView(for tabId: UUID) {
        if let wv = webViews.removeValue(forKey: tabId) {
            wv.stopLoading()
            wv.removeFromSuperview()
        }
    }
    
    /// Clears all cached web views (e.g. during memory pressure or reset). Safe to call from any thread or actor.
    public func clearAllWebViews() {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                self.performClearAll()
            }
        } else {
            DispatchQueue.main.async {
                self.performClearAll()
            }
        }
    }
    
    @MainActor
    private func performClearAll() {
        for (_, wv) in webViews {
            wv.stopLoading()
            wv.removeFromSuperview()
        }
        webViews.removeAll()
    }
}

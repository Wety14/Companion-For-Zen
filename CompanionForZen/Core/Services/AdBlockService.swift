import Foundation
import WebKit

/// Service responsible for native WebKit content blocking (Ads, Trackers, Cookie popups).
/// Injects declarative WKContentRuleList rules for zero-CPU filtering and a UserScript to auto-dismiss consent overlays.
public final class AdBlockService: ObservableObject {
    public static let shared = AdBlockService()
    
    @Published public var blockedElementsSessionCount: Int = 0
    @Published public var totalBlockedCount: Int {
        didSet {
            UserDefaults.standard.set(totalBlockedCount, forKey: "total_blocked_count")
        }
    }
    
    @Published public var disabledDomains: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(disabledDomains), forKey: "adblock_disabled_domains")
        }
    }
    
    @Published public var stripTrackingParameters: Bool {
        didSet {
            UserDefaults.standard.set(stripTrackingParameters, forKey: "adblock_strip_tracking_parameters")
        }
    }
    
    private var contentRuleList: WKContentRuleList?
    
    private init() {
        self.totalBlockedCount = UserDefaults.standard.integer(forKey: "total_blocked_count")
        let savedDomains = UserDefaults.standard.stringArray(forKey: "adblock_disabled_domains") ?? []
        self.disabledDomains = Set(savedDomains)
        if UserDefaults.standard.object(forKey: "adblock_strip_tracking_parameters") == nil {
            self.stripTrackingParameters = true
        } else {
            self.stripTrackingParameters = UserDefaults.standard.bool(forKey: "adblock_strip_tracking_parameters")
        }
        compileRules()
    }
    
    public func recordBlocked() {
        DispatchQueue.main.async {
            self.blockedElementsSessionCount += 1
            self.totalBlockedCount += 1
        }
    }
    
    /// Extract normalized domain name from URL (removes 'www.' prefix)
    public func domain(for url: URL?) -> String? {
        guard let host = url?.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
    
    /// Check if Zen Protection is active for a specific URL / domain
    public func isProtectionEnabled(for url: URL?) -> Bool {
        guard let dom = domain(for: url) else { return true }
        return !disabledDomains.contains(dom)
    }
    
    /// Toggle Zen Protection for a specific URL / domain persistently
    public func toggleProtection(for url: URL?) {
        guard let dom = domain(for: url) else { return }
        if disabledDomains.contains(dom) {
            disabledDomains.remove(dom)
        } else {
            disabledDomains.insert(dom)
        }
    }
    
    /// Explicitly set Zen Protection state for a domain
    public func setProtection(enabled: Bool, for url: URL?) {
        guard let dom = domain(for: url) else { return }
        if enabled {
            disabledDomains.remove(dom)
        } else {
            disabledDomains.insert(dom)
        }
    }
    
    /// Dynamically update WKWebView content rules based on the site's protection setting
    public func updateWebViewBlocking(webView: WKWebView, for url: URL?) {
        let enabled = isProtectionEnabled(for: url)
        let userContentController = webView.configuration.userContentController
        
        // Remove existing content rules
        userContentController.removeAllContentRuleLists()
        
        // Only inject blocker rules if protection is enabled on this domain
        if enabled, let ruleList = contentRuleList {
            userContentController.add(ruleList)
        }
    }
    
    /// Compile or load cached native WebKit rules
    public func compileRules(forceRecompile: Bool = false, completion: (() -> Void)? = nil) {
        if !forceRecompile {
            WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: "CompanionZenRules") { [weak self] existingList, error in
                if let existingList = existingList {
                    DispatchQueue.main.async {
                        self?.contentRuleList = existingList
                        completion?()
                    }
                    return
                }
                self?.performRuleCompilation(completion: completion)
            }
        } else {
            performRuleCompilation(completion: completion)
        }
    }
    
    private func performRuleCompilation(completion: (() -> Void)? = nil) {
        let blockedPatterns = [
            "doubleclick\\.net",
            "googlesyndication\\.com",
            "google-analytics\\.com",
            "adservice\\.google\\.com",
            "adnxs\\.com",
            "criteo\\.com",
            "outbrain\\.com",
            "taboola\\.com",
            "quantserve\\.com",
            "scorecardresearch\\.com",
            "hotjar\\.com",
            "segment\\.io",
            "facebook\\.net/.*fbevents",
            "adsystem\\.com",
            "cookiebot\\.com",
            "onetrust\\.com",
            "didomi\\.io",
            "quantcast\\.mgr\\.consensu\\.org",
            "trustarc\\.com",
            "civiccomputing\\.com"
        ]
        
        var ruleDictionaries: [[String: Any]] = blockedPatterns.map { pattern in
            [
                "trigger": [
                    "url-filter": ".*" + pattern + ".*"
                ],
                "action": [
                    "type": "block"
                ]
            ]
        }
        
        ruleDictionaries.append([
            "trigger": [
                "url-filter": ".*"
            ],
            "action": [
                "type": "css-display-none",
                "selector": "#onetrust-consent-sdk, .onetrust-pc-dark-filter, #cmpbox, #didomi-host, .cc-banner, .cookie-banner, .cookie-consent, #cookie-law-info-bar, [id*='cookie-consent'], [class*='cookie-notice'], [class*='consent-modal'], .sp_message_container, #CybotCookiebotDialog"
            ]
        ])
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ruleDictionaries, options: []),
              let rulesJSON = String(data: jsonData, encoding: .utf8) else {
            completion?()
            return
        }
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "CompanionZenRules",
            encodedContentRuleList: rulesJSON
        ) { [weak self] ruleList, error in
            if let error = error {
                print("Failed to compile WKContentRuleList: \(error)")
            } else if let ruleList = ruleList {
                DispatchQueue.main.async {
                    self?.contentRuleList = ruleList
                }
            }
            completion?()
        }
    }
    
    public func applyTo(configuration: WKWebViewConfiguration, url: URL? = nil) {
        if isProtectionEnabled(for: url), let ruleList = contentRuleList {
            configuration.userContentController.add(ruleList)
        }
        
        // Inject Cookie Banner Auto-Closer & Scroll Unblocker script
        let cookieDismissScript = """
        (function() {
            function autoDismissCookies() {
                // Selectors for common cookie reject/accept/close buttons
                const selectors = [
                    '#onetrust-accept-btn-handler',
                    '#didomi-notice-agree-button',
                    '.didomi-continue-without-agreeing',
                    'button[id*="cookie-accept"]',
                    'button[class*="cookie-accept"]',
                    'button[aria-label*="Accept"]',
                    'button[aria-label*="Accepter"]',
                    '.cc-btn.cc-dismiss',
                    '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll'
                ];
                for (const sel of selectors) {
                    const btn = document.querySelector(sel);
                    if (btn && typeof btn.click === 'function') {
                        btn.click();
                        break;
                    }
                }
                // Unlock body overflow if banner locked scrolling
                if (document.body && document.body.style) {
                    if (document.body.style.overflow === 'hidden') {
                        document.body.style.overflow = 'auto';
                    }
                }
            }
            if (document.readyState === 'complete' || document.readyState === 'interactive') {
                autoDismissCookies();
            } else {
                document.addEventListener('DOMContentLoaded', autoDismissCookies);
            }
            setTimeout(autoDismissCookies, 1000);
            setTimeout(autoDismissCookies, 2500);
        })();
        """
        
        let userScript = WKUserScript(
            source: cookieDismissScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)
    }

    // MARK: - URL Tracker Stripping
    
    private static let knownTrackingParameters: Set<String> = [
        // Analytics & Campaigns (UTM)
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_cid", "utm_reader", "utm_name", "utm_pubreferrer", "utm_swu", "utm_viz_id",
        // Facebook & Meta
        "fbclid", "fbadid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
        // Instagram
        "igshid", "igsh", "share_id",
        // Twitter / X
        "ref_src", "ref_url", "twclid",
        // Google & YouTube
        "gclid", "gclsrc", "dclid", "gad_source", "gbraid", "wbraid", "si", "_ga", "glsr",
        "gs_l", "ved", "ei", "sei",
        // Microsoft & Bing
        "msclkid",
        // TikTok
        "_r", "_t", "checksum", "sec_user_id", "tt_medium", "tt_content",
        // Email Marketing & CRMs
        "mc_eid", "mc_cid", "_hsenc", "_hsmi", "mkt_tok", "vero_id", "vero_conv", "wickedid",
        // Generic & Affiliate Tracking
        "yclid", "zanpid", "rb_clickid", "s_kwcid", "s_campaign", "ref", "affiliate", "spm", "scm"
    ]
    
    /// Cleans and sanitizes a URL by stripping marketing and social trackers (Instagram igsh, Facebook fbclid, UTM, etc.)
    public func cleanTrackingParameters(from url: URL) -> URL {
        guard stripTrackingParameters else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return url
        }
        
        let filteredItems = queryItems.filter { item in
            let name = item.name.lowercased()
            if name.hasPrefix("utm_") {
                return false
            }
            // Twitter / X single-character tracking parameters
            if (name == "t" || name == "s") && (components.host?.contains("twitter.com") == true || components.host?.contains("x.com") == true) {
                return false
            }
            return !Self.knownTrackingParameters.contains(name)
        }
        
        components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        return components.url ?? url
    }
    
    /// Cleans tracking parameters from a URL string if valid
    public func cleanTrackingParameters(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return cleanTrackingParameters(from: url).absoluteString
    }

}

import Foundation
import UIKit
import Combine

/// Service managing Apple Handoff (Continuity) between Zen Browser macOS and Companion for Zen iOS.
/// Broadcasts the current webpage using standard `NSUserActivityTypeBrowsingWeb` and custom Zen activities.
public final class HandoffService: ObservableObject {
    public static let shared = HandoffService()
    
    public static let browsingActivityType = NSUserActivityTypeBrowsingWeb
    public static let zenCompanionActivityType = "app.zenbrowser.companion.browsing"
    
    @Published public var isHandoffEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHandoffEnabled, forKey: "handoff_enabled")
            if !isHandoffEnabled {
                invalidateCurrentActivity()
            }
        }
    }
    
    @Published public var incomingHandoffURL: URL?
    @Published public var incomingHandoffTitle: String?
    @Published public var showIncomingHandoffBanner: Bool = false
    
    private var currentActivity: NSUserActivity?
    
    private init() {
        self.isHandoffEnabled = UserDefaults.standard.object(forKey: "handoff_enabled") as? Bool ?? true
    }
    
    /// Broadcast the active tab to nearby Apple devices (macOS Zen Browser, iPad, etc.)
    public func broadcastTab(url: URL?, title: String, spaceName: String? = nil) {
        guard isHandoffEnabled, let url = url, url.scheme == "http" || url.scheme == "https" else {
            invalidateCurrentActivity()
            return
        }
        
        let activity = NSUserActivity(activityType: Self.browsingActivityType)
        activity.title = title.isEmpty ? (url.host ?? "Zen Browser") : title
        activity.webpageURL = url
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false
        
        var userInfo: [String: Any] = [
            "url": url.absoluteString,
            "title": title
        ]
        if let space = spaceName {
            userInfo["space"] = space
        }
        activity.userInfo = userInfo
        activity.requiredUserInfoKeys = Set(["url"])
        
        // Become active
        activity.becomeCurrent()
        self.currentActivity = activity
    }
    
    /// Handle incoming Handoff from macOS Zen Browser
    public func handleIncomingUserActivity(_ userActivity: NSUserActivity) -> URL? {
        guard isHandoffEnabled else { return nil }
        
        var targetURL: URL?
        var pageTitle = userActivity.title ?? "Page transmise depuis le Mac"
        
        if let webURL = userActivity.webpageURL {
            targetURL = webURL
        } else if let urlStr = userActivity.userInfo?["url"] as? String, let parsed = URL(string: urlStr) {
            targetURL = parsed
        }
        
        if let title = userActivity.userInfo?["title"] as? String, !title.isEmpty {
            pageTitle = title
        }
        
        if let url = targetURL {
            DispatchQueue.main.async {
                self.incomingHandoffURL = url
                self.incomingHandoffTitle = pageTitle
                self.showIncomingHandoffBanner = true
                Haptics.success()
            }
            return url
        }
        
        return nil
    }
    
    public func dismissIncomingBanner() {
        showIncomingHandoffBanner = false
        incomingHandoffURL = nil
        incomingHandoffTitle = nil
    }
    
    public func invalidateCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }
}

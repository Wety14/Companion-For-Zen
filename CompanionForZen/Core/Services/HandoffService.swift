import Foundation
import UIKit
import Combine

/// Service managing Apple Handoff (Continuity) between Zen Browser macOS and Companion for Zen iOS.
/// Broadcasts the current webpage using standard `NSUserActivityTypeBrowsingWeb` and custom Zen activities.
public final class HandoffService: ObservableObject {
    public static let shared = HandoffService()
    
    public static let browsingActivityType = NSUserActivityTypeBrowsingWeb
    public static let zenCompanionActivityType = "app.zen-browser.companion.browsing"
    
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
    
    /// Broadcast the current tab to nearby Apple devices via Handoff
    public func broadcastTab(url: URL?, title: String?, spaceName: String? = nil, isPrivate: Bool = false) {
        guard isHandoffEnabled, !isPrivate, let url = url, url.scheme == "http" || url.scheme == "https" else {
            invalidateCurrentActivity()
            return
        }
        
        let activity = NSUserActivity(activityType: HandoffService.browsingActivityType)
        activity.webpageURL = url
        activity.title = title ?? url.host ?? "Zen Browser"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = !isPrivate
        activity.isEligibleForPublicIndexing = false
        
        var userInfo: [String: Any] = [
            "url": url.absoluteString,
            "title": title ?? ""
        ]
        if let space = spaceName {
            userInfo["spaceName"] = space
        }
        activity.userInfo = userInfo
        activity.requiredUserInfoKeys = ["url"]
        
        activity.becomeCurrent()
        self.currentActivity = activity
    }
    
    /// Invalidate existing handoff broadcast
    public func invalidateCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }
    
    /// Handle an incoming NSUserActivity from another device
    public func handleIncomingUserActivity(_ activity: NSUserActivity) -> URL? {
        if let webpageURL = activity.webpageURL {
            self.incomingHandoffURL = webpageURL
            self.incomingHandoffTitle = activity.title
            return webpageURL
        }
        
        if let urlString = activity.userInfo?["url"] as? String, let url = URL(string: urlString) {
            self.incomingHandoffURL = url
            self.incomingHandoffTitle = activity.userInfo?["title"] as? String ?? activity.title
            return url
        }
        
        return nil
    }
}

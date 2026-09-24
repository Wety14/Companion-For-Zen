import Foundation
import Combine
import SwiftUI

/// Central state manager for Tabs, Spaces, and Automatic Archiving.
/// Follows Clean Architecture so the state logic can be directly copied or translated to Kotlin/Android.
public final class TabManager: ObservableObject {
    public static let shared = TabManager()
    
    @Published public var spaces: [Space] = []
    @Published public var activeSpaceId: UUID
    @Published public var tabs: [Tab] = []
    @Published public var activeTabId: UUID?
    @Published public var archivedTabs: [Tab] = []
    
    private let tabsKey = "companion_zen_tabs"
    private let spacesKey = "companion_zen_spaces"
    private let archivedTabsKey = "companion_zen_archived_tabs"
    private let activeSpaceKey = "companion_zen_active_space"
    
    private var archiveTimer: Timer?
    
    public init() {
        // Load Spaces
        let loadedSpaces: [Space]
        if let data = UserDefaults.standard.data(forKey: spacesKey),
           let savedSpaces = try? JSONDecoder().decode([Space].self, from: data),
           !savedSpaces.isEmpty {
            loadedSpaces = savedSpaces
        } else {
            loadedSpaces = Space.defaultSpaces
        }
        
        let initialSpaceId: UUID
        if let savedSpaceStr = UserDefaults.standard.string(forKey: activeSpaceKey),
           let savedUUID = UUID(uuidString: savedSpaceStr),
           loadedSpaces.contains(where: { $0.id == savedUUID }) {
            initialSpaceId = savedUUID
        } else {
            initialSpaceId = loadedSpaces.first?.id ?? UUID()
        }
        
        // Load Tabs
        let loadedTabs: [Tab]
        if let data = UserDefaults.standard.data(forKey: tabsKey),
           let savedTabs = try? JSONDecoder().decode([Tab].self, from: data),
           !savedTabs.isEmpty {
            loadedTabs = savedTabs
        } else {
            let defaultTab = Tab(
                url: URL(string: "https://duckduckgo.com")!,
                title: "DuckDuckGo",
                spaceId: initialSpaceId
            )
            loadedTabs = [defaultTab]
        }
        
        // Load Archived Tabs
        let loadedArchived: [Tab]
        if let data = UserDefaults.standard.data(forKey: archivedTabsKey),
           let savedArchived = try? JSONDecoder().decode([Tab].self, from: data) {
            loadedArchived = savedArchived
        } else {
            loadedArchived = []
        }
        
        // Pick active tab in current space
        let activeTabInSpace = loadedTabs.first(where: { $0.spaceId == initialSpaceId && !$0.isArchived })
        let initialActiveTabId = activeTabInSpace?.id ?? loadedTabs.first?.id
        
        self.spaces = loadedSpaces
        self.activeSpaceId = initialSpaceId
        self.tabs = loadedTabs
        self.archivedTabs = loadedArchived
        self.activeTabId = initialActiveTabId
        
        // Run auto-archive check and start periodic timer
        performAutoArchiveCheck()
        scheduleArchiveTimer()
    }
    
    // MARK: - Spaces Accessors
    
    public var activeSpace: Space {
        spaces.first(where: { $0.id == activeSpaceId }) ?? spaces.first ?? Space(name: "Principal")
    }
    
    public func selectSpace(_ space: Space) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.activeSpaceId = space.id
            UserDefaults.standard.set(space.id.uuidString, forKey: activeSpaceKey)
            
            // Switch to first active tab of this space or create one
            let spaceTabs = activeTabs(for: space.id)
            if let first = spaceTabs.first {
                self.activeTabId = first.id
            } else {
                let newTab = Tab(url: URL(string: "https://duckduckgo.com")!, spaceId: space.id)
                self.tabs.append(newTab)
                self.activeTabId = newTab.id
                save()
            }
        }
    }
    
    public func addSpace(name: String, iconName: String, colorHex: String) {
        let newSpace = Space(
            name: name,
            iconName: iconName,
            themeColorHex: colorHex,
            order: spaces.count
        )
        spaces.append(newSpace)
        selectSpace(newSpace)
        save()
    }
    
    // MARK: - Tab Filters for current space
    
    public func pinnedTabs(for spaceId: UUID) -> [Tab] {
        tabs.filter { $0.spaceId == spaceId && $0.isPinned && !$0.isArchived }
    }
    
    public func todayTabs(for spaceId: UUID) -> [Tab] {
        tabs.filter { $0.spaceId == spaceId && !$0.isPinned && !$0.isArchived }
    }
    
    public func activeTabs(for spaceId: UUID) -> [Tab] {
        tabs.filter { $0.spaceId == spaceId && !$0.isArchived }
    }
    
    public var activeTab: Tab? {
        guard let id = activeTabId else { return nil }
        return tabs.first(where: { $0.id == id })
    }
    
    // MARK: - Tab Actions
    
    @discardableResult
    public func openNewTab(url: URL = URL(string: "https://duckduckgo.com")!, spaceId: UUID? = nil) -> Tab {
        let targetSpace = spaceId ?? activeSpaceId
        let newTab = Tab(url: url, spaceId: targetSpace)
        tabs.append(newTab)
        activeTabId = newTab.id
        save()
        return newTab
    }
    
    public func selectTab(_ tab: Tab) {
        activeTabId = tab.id
        if tab.spaceId != activeSpaceId {
            activeSpaceId = tab.spaceId
            UserDefaults.standard.set(tab.spaceId.uuidString, forKey: activeSpaceKey)
        }
        touchTab(tab.id)
    }
    
    public func touchTab(_ tabId: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[idx].lastAccessedAt = Date()
            save()
        }
    }
    
    public func updateActiveTab(url: URL, title: String) {
        guard let id = activeTabId, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].url = url
        tabs[idx].title = title
        tabs[idx].lastAccessedAt = Date()
        save()
    }
    
    public func togglePin(tabId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tabs[idx].isPinned.toggle()
            save()
        }
    }
    
    public func closeTab(tabId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let targetSpace = tabs[idx].spaceId
        
        withAnimation(.easeInOut(duration: 0.2)) {
            tabs.remove(at: idx)
            
            // If closed tab was active, choose next tab in space
            if activeTabId == tabId {
                let remaining = activeTabs(for: targetSpace)
                activeTabId = remaining.first?.id
            }
            save()
        }
    }
    
    public func moveTabToSpace(tabId: UUID, newSpaceId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].spaceId = newSpaceId
        save()
    }
    
    /// Replace spaces and tabs with synced desktop data
    public func replaceSpacesAndTabs(newSpaces: [Space], newTabs: [Tab]) {
        guard !newSpaces.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            self.spaces = newSpaces
            self.tabs = newTabs
            self.activeSpaceId = newSpaces.first!.id
            self.activeTabId = newTabs.first(where: { $0.spaceId == self.activeSpaceId })?.id ?? newTabs.first?.id
            save()
        }
    }
    
    // MARK: - Auto-Archive System (Arc-like)
    
    public func performAutoArchiveCheck(policy: AutoArchivePolicy = .twentyFourHours) {
        guard let thresholdSeconds = policy.timeInterval else { return }
        let now = Date()
        
        var toArchive: [Tab] = []
        var toKeep: [Tab] = []
        
        for var tab in tabs {
            // Pinned tabs are NEVER auto-archived
            if tab.isPinned {
                toKeep.append(tab)
                continue
            }
            
            let elapsed = now.timeIntervalSince(tab.lastAccessedAt)
            if elapsed >= thresholdSeconds {
                tab.isArchived = true
                tab.archivedAt = now
                toArchive.append(tab)
            } else {
                toKeep.append(tab)
            }
        }
        
        if !toArchive.isEmpty {
            self.tabs = toKeep
            self.archivedTabs.insert(contentsOf: toArchive, at: 0)
            
            // If current tab got archived, select another active tab
            if let cur = activeTabId, toArchive.contains(where: { $0.id == cur }) {
                let currentSpaceRemaining = activeTabs(for: activeSpaceId)
                self.activeTabId = currentSpaceRemaining.first?.id ?? openNewTab().id
            }
            save()
        }
    }
    
    public func restoreArchivedTab(_ tab: Tab) {
        guard let idx = archivedTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        var restored = archivedTabs.remove(at: idx)
        restored.isArchived = false
        restored.archivedAt = nil
        restored.lastAccessedAt = Date()
        
        tabs.append(restored)
        activeSpaceId = restored.spaceId
        activeTabId = restored.id
        save()
    }
    
    public func deleteArchivedTab(_ tab: Tab) {
        archivedTabs.removeAll(where: { $0.id == tab.id })
        save()
    }
    
    public func clearAllArchivedTabs() {
        archivedTabs.removeAll()
        save()
    }
    
    private func scheduleArchiveTimer() {
        archiveTimer?.invalidate()
        // Check every 30 minutes
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.performAutoArchiveCheck()
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(data, forKey: tabsKey)
        }
        if let data = try? JSONEncoder().encode(spaces) {
            UserDefaults.standard.set(data, forKey: spacesKey)
        }
        if let data = try? JSONEncoder().encode(archivedTabs) {
            UserDefaults.standard.set(data, forKey: archivedTabsKey)
        }
    }
}

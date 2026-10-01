import Foundation
import Combine
import SwiftUI

/// Central state manager for Tabs, Spaces, and Automatic Archiving.
/// Follows Clean Architecture so the state logic can be directly copied or translated to Kotlin/Android.
public final class TabManager: ObservableObject {
    public static let shared = TabManager()
    public static let appGroupId = "group.app.zen-browser.companion"
    public static let zenWebsiteURL = URL(string: "https://zen-browser.app")!
    
    @Published public var spaces: [Space] = []
    @Published public var activeSpaceId: UUID
    @Published public var tabs: [Tab] = []
    @Published public var folders: [ZenFolder] = []
    @Published public var activeTabId: UUID?
    @Published public var archivedTabs: [Tab] = []
    @Published public var shouldOpenSearchOnEmptySpaceSwitch: Bool = false
    
    private let tabsKey = "companion_zen_tabs"
    private let spacesKey = "companion_zen_spaces"
    private let foldersKey = "companion_zen_folders"
    private let archivedTabsKey = "companion_zen_archived_tabs"
    private let activeSpaceKey = "companion_zen_active_space"
    private let didOverwriteLegacyThemesV2Key = "companion_zen_did_overwrite_legacy_themes_v2"
    
    private var archiveTimer: Timer?
    
    public static let isAppGroupAvailable: Bool = {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return false
        }
        let testFile = containerURL.appendingPathComponent(".zen_container_check")
        do {
            try "ok".write(to: testFile, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }()
    
    public static var safeDefaults: UserDefaults {
        if isAppGroupAvailable, let suite = UserDefaults(suiteName: appGroupId) {
            return suite
        }
        return .standard
    }
    
    private var defaults: UserDefaults {
        TabManager.safeDefaults
    }
    
    public init() {
        let storage = TabManager.safeDefaults
        // Migrate data from standard UserDefaults to App Group suite if needed
        if storage !== UserDefaults.standard {
            if storage.data(forKey: spacesKey) == nil, let std = UserDefaults.standard.data(forKey: spacesKey) {
                storage.set(std, forKey: spacesKey)
            }
            if storage.data(forKey: tabsKey) == nil, let std = UserDefaults.standard.data(forKey: tabsKey) {
                storage.set(std, forKey: tabsKey)
            }
            if storage.data(forKey: foldersKey) == nil, let std = UserDefaults.standard.data(forKey: foldersKey) {
                storage.set(std, forKey: foldersKey)
            }
            if storage.data(forKey: archivedTabsKey) == nil, let std = UserDefaults.standard.data(forKey: archivedTabsKey) {
                storage.set(std, forKey: archivedTabsKey)
            }
            if storage.string(forKey: activeSpaceKey) == nil, let std = UserDefaults.standard.string(forKey: activeSpaceKey) {
                storage.set(std, forKey: activeSpaceKey)
            }
        }
        let didOverwriteThemesV2 = storage.bool(forKey: didOverwriteLegacyThemesV2Key)
        
        // Load Spaces & Overwrite Legacy Themes
        var loadedSpaces: [Space]
        if !didOverwriteThemesV2 {
            if let data = storage.data(forKey: spacesKey),
               let savedSpaces = try? JSONDecoder().decode([Space].self, from: data),
               !savedSpaces.isEmpty {
                loadedSpaces = TabManager.forceOverwriteAllSpacesToZenGradients(savedSpaces)
            } else {
                loadedSpaces = Space.defaultSpaces
            }
            storage.set(true, forKey: didOverwriteLegacyThemesV2Key)
            UserDefaults.standard.set(true, forKey: didOverwriteLegacyThemesV2Key)
        } else {
            if let data = storage.data(forKey: spacesKey),
               let savedSpaces = try? JSONDecoder().decode([Space].self, from: data),
               !savedSpaces.isEmpty {
                loadedSpaces = TabManager.overwriteLegacyThemes(in: savedSpaces)
            } else {
                loadedSpaces = Space.defaultSpaces
            }
        }
        
        let initialSpaceId: UUID
        if let savedSpaceStr = storage.string(forKey: activeSpaceKey),
           let savedUUID = UUID(uuidString: savedSpaceStr),
           loadedSpaces.contains(where: { $0.id == savedUUID }) {
            initialSpaceId = savedUUID
        } else {
            initialSpaceId = loadedSpaces.first?.id ?? UUID()
        }
        
        // Load Tabs
        var loadedTabs: [Tab]
        if let data = storage.data(forKey: tabsKey),
           let savedTabs = try? JSONDecoder().decode([Tab].self, from: data) {
            loadedTabs = savedTabs
        } else {
            loadedTabs = []
        }
        
        // Automatically purge any stale mock tabs (e.g. YouTube, Reddit from previous versions)
        let didPurgeMockKey = "companion_did_purge_initial_mock_v2"
        if !storage.bool(forKey: didPurgeMockKey) {
            let containsLegacyMock = loadedTabs.contains(where: {
                $0.url.host?.contains("youtube.com") == true ||
                $0.url.host?.contains("reddit.com") == true ||
                $0.title.lowercased() == "youtube" ||
                $0.title.lowercased() == "reddit"
            })
            if containsLegacyMock {
                loadedSpaces = Space.defaultSpaces
                let defaultSpaceId = loadedSpaces.first?.id ?? UUID()
                loadedTabs = [
                    Tab(url: TabManager.zenWebsiteURL, title: "Zen Browser", spaceId: defaultSpaceId)
                ]
                if let data = try? JSONEncoder().encode(loadedTabs) {
                    storage.set(data, forKey: tabsKey)
                }
                if let data = try? JSONEncoder().encode(loadedSpaces) {
                    storage.set(data, forKey: spacesKey)
                }
            }
            storage.set(true, forKey: didPurgeMockKey)
            UserDefaults.standard.set(true, forKey: didPurgeMockKey)
        }
        
        // Load Archived Tabs
        let loadedArchived: [Tab]
        if let data = storage.data(forKey: archivedTabsKey),
           let savedArchived = try? JSONDecoder().decode([Tab].self, from: data) {
            loadedArchived = savedArchived
        } else {
            loadedArchived = []
        }
        
        // Load Folders
        let loadedFolders: [ZenFolder]
        if let data = storage.data(forKey: foldersKey),
           let savedFolders = try? JSONDecoder().decode([ZenFolder].self, from: data) {
            loadedFolders = savedFolders
        } else {
            loadedFolders = []
        }
        
        self.spaces = loadedSpaces
        self.activeSpaceId = initialSpaceId
        self.tabs = loadedTabs
        self.folders = loadedFolders
        self.archivedTabs = loadedArchived
        
        // If there's an existing tab for the active space, select it
        if let firstTabInSpace = loadedTabs.first(where: { $0.spaceId == initialSpaceId && !$0.isPinned && !$0.isFavorite }) {
            self.activeTabId = firstTabInSpace.id
        } else if let firstOpen = loadedTabs.first(where: { !$0.isPinned && !$0.isFavorite && !$0.isArchived }) {
            self.activeTabId = firstOpen.id
        } else {
            self.activeTabId = nil
        }
        self.save() // Definitively persist overwritten Zen gradient themes and default tab to storage
        
        scheduleArchiveTimer()
    }
    
    /// Reload spaces and tabs directly from App Group storage (e.g. after share extension modified them)
    public func reloadFromDisk() {
        let storage = defaults
        if let spacesData = storage.data(forKey: spacesKey),
           let savedSpaces = try? JSONDecoder().decode([Space].self, from: spacesData),
           !savedSpaces.isEmpty {
            self.spaces = TabManager.overwriteLegacyThemes(in: savedSpaces)
        }
        
        if let foldersData = storage.data(forKey: foldersKey),
           let savedFolders = try? JSONDecoder().decode([ZenFolder].self, from: foldersData) {
            self.folders = savedFolders
        }
        
        if let tabsData = storage.data(forKey: tabsKey),
           let savedTabs = try? JSONDecoder().decode([Tab].self, from: tabsData) {
            // Preserve private tabs currently in memory
            let currentPrivateTabs = self.tabs.filter { $0.isPrivate }
            if savedTabs.isEmpty && currentPrivateTabs.isEmpty {
                self.tabs = []
                self.activeTabId = nil
            } else {
                self.tabs = savedTabs + currentPrivateTabs
                if let activeId = self.activeTabId, !self.tabs.contains(where: { $0.id == activeId }) {
                    self.activeTabId = self.openTabs.first?.id
                }
            }
        } else if self.tabs.isEmpty {
            self.activeTabId = nil
        }
    }
    
    // MARK: - Space Management
    
    public var activeSpace: Space {
        spaces.first(where: { $0.id == activeSpaceId }) ?? spaces.first ?? Space.defaultSpaces.first!
    }
    
    public func selectSpace(_ space: Space) {
        switchSpace(to: space.id)
    }
    
    public func switchSpace(to spaceId: UUID) {
        guard spaces.contains(where: { $0.id == spaceId }) else { return }
        activeSpaceId = spaceId
        defaults.set(spaceId.uuidString, forKey: activeSpaceKey)
        UserDefaults.standard.set(spaceId.uuidString, forKey: activeSpaceKey)
        // Decoupled: Switching spaces acts as browsing a bank of links; it does not change the open tab in the background.
    }

    public func switchToNextSpaceCircular() {
        guard !spaces.isEmpty else { return }
        let sortedSpaces = spaces.sorted(by: { $0.order < $1.order })
        guard let currentIndex = sortedSpaces.firstIndex(where: { $0.id == activeSpaceId }) else {
            switchSpace(to: sortedSpaces.first!.id)
            return
        }
        let nextIndex = (currentIndex + 1) % sortedSpaces.count
        switchSpace(to: sortedSpaces[nextIndex].id)
    }

    public func switchToPreviousSpaceCircular() {
        guard !spaces.isEmpty else { return }
        let sortedSpaces = spaces.sorted(by: { $0.order < $1.order })
        guard let currentIndex = sortedSpaces.firstIndex(where: { $0.id == activeSpaceId }) else {
            switchSpace(to: sortedSpaces.first!.id)
            return
        }
        let prevIndex = (currentIndex - 1 + sortedSpaces.count) % sortedSpaces.count
        switchSpace(to: sortedSpaces[prevIndex].id)
    }

    public func moveSpace(fromIndex: Int, toIndex: Int) {
        spaces.sort(by: { $0.order < $1.order })
        guard fromIndex >= 0, fromIndex < spaces.count,
              toIndex >= 0, toIndex < spaces.count,
              fromIndex != toIndex else { return }
        let space = spaces.remove(at: fromIndex)
        spaces.insert(space, at: toIndex)
        for i in 0..<spaces.count {
            spaces[i].order = i
        }
        save()
    }

    public func moveSpace(spaceId: UUID, toIndex: Int) {
        spaces.sort(by: { $0.order < $1.order })
        guard let fromIndex = spaces.firstIndex(where: { $0.id == spaceId }),
              toIndex >= 0, toIndex < spaces.count,
              fromIndex != toIndex else { return }
        let space = spaces.remove(at: fromIndex)
        spaces.insert(space, at: toIndex)
        for i in 0..<spaces.count {
            spaces[i].order = i
        }
        save()
    }
    
    public func addSpace(
        name: String,
        iconName: String,
        profileId: String = "Personnel",
        colorHex: String? = nil,
        gradientColorsHex: [String]? = nil,
        gradientOpacity: Double? = nil,
        gradientTexture: Double? = nil,
        gradientScheme: String? = nil
    ) -> Space {
        let colors: [String]
        if let g = gradientColorsHex, g.count >= 2 {
            colors = g
        } else if let c = colorHex {
            colors = Space.generateZenGradient(fromBaseHex: c)
        } else {
            colors = ["#537CF7", "#F27F59", "#CBF259"]
        }
        
        let newSpace = Space(
            name: name,
            iconName: iconName,
            profileId: profileId,
            order: spaces.count,
            gradientColorsHex: colors,
            gradientOpacity: gradientOpacity ?? 0.55,
            gradientTexture: gradientTexture ?? 0.2,
            gradientScheme: gradientScheme ?? "auto"
        )
        spaces.append(newSpace)
        save()
        return newSpace
    }
    
    /// Unconditionally overwrite all spaces with official Zen 3-color harmonic gradients
    public static func forceOverwriteAllSpacesToZenGradients(_ spaces: [Space]) -> [Space] {
        return spaces.enumerated().map { index, space in
            var updated = space
            if space.name == "Personnel" || index == 0 {
                updated.gradientColorsHex = ["#537CF7", "#F27F59", "#CBF259"]
            } else if space.name == "Travail" || index == 1 {
                updated.gradientColorsHex = ["#F76F53", "#59F2BF", "#598BF2"]
            } else if space.name == "Détente" || index == 2 {
                updated.gradientColorsHex = ["#2A9D8F", "#B53083", "#B56330"]
            } else {
                updated.gradientColorsHex = Space.generateZenGradient(fromBaseHex: space.primaryColorHex)
            }
            updated.gradientOpacity = 0.55
            updated.gradientTexture = 0.2
            updated.gradientScheme = "auto"
            return updated
        }
    }

    /// Overwrites legacy single-color or outdated themes on already created spaces
    /// and migrates them definitively to the new Zen gradient system.
    public static func overwriteLegacyThemes(in spaces: [Space]) -> [Space] {
        return spaces.map { space in
            var updated = space
            if space.name == "Personnel" {
                updated.gradientColorsHex = ["#537CF7", "#F27F59", "#CBF259"]
                updated.gradientOpacity = 0.55
                updated.gradientTexture = 0.2
                updated.gradientScheme = "auto"
            } else if space.name == "Travail" {
                updated.gradientColorsHex = ["#F76F53", "#59F2BF", "#598BF2"]
                updated.gradientOpacity = 0.55
                updated.gradientTexture = 0.2
                updated.gradientScheme = "auto"
            } else if space.name == "Détente" {
                updated.gradientColorsHex = ["#2A9D8F", "#B53083", "#B56330"]
                updated.gradientOpacity = 0.55
                updated.gradientTexture = 0.2
                updated.gradientScheme = "auto"
            } else {
                if updated.gradientColorsHex.count < 3 || Set(updated.gradientColorsHex).count < 2 {
                    updated.gradientColorsHex = Space.generateZenGradient(fromBaseHex: space.primaryColorHex)
                    updated.gradientOpacity = 0.55
                    updated.gradientTexture = 0.2
                    updated.gradientScheme = "auto"
                }
            }
            return updated
        }
    }
    
    public func saveToDisk() {
        save()
    }
    
    /// Reset spaces and tabs back to pristine defaults, purging any legacy mock or migrated data.
    public func resetToDefaultSpacesAndTabs() {
        self.spaces = Space.defaultSpaces
        self.activeSpaceId = self.spaces.first?.id ?? UUID()
        self.tabs = [
            Tab(url: URL(string: "https://zen-browser.app")!, title: "Zen Browser", spaceId: self.activeSpaceId)
        ]
        self.folders = []
        self.archivedTabs = []
        self.activeTabId = self.tabs.first?.id
        save()
        Haptics.medium()
    }

    public func updateSpace(_ space: Space) {
        if let index = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[index] = space
            save()
        }
    }

    public func updateSpace(
        id: UUID,
        name: String,
        iconName: String,
        profileId: String = "Personnel",
        gradientColorsHex: [String],
        gradientOpacity: Double,
        gradientTexture: Double,
        gradientScheme: String
    ) {
        if let index = spaces.firstIndex(where: { $0.id == id }) {
            spaces[index].name = name
            spaces[index].iconName = iconName
            spaces[index].profileId = profileId
            spaces[index].gradientColorsHex = gradientColorsHex
            spaces[index].gradientOpacity = gradientOpacity
            spaces[index].gradientTexture = gradientTexture
            spaces[index].gradientScheme = gradientScheme
            save()
        }
    }
    
    public func deleteSpace(_ space: Space) {
        guard spaces.count > 1 else { return } // Keep at least one space
        tabs.removeAll(where: { $0.spaceId == space.id })
        archivedTabs.removeAll(where: { $0.spaceId == space.id })
        spaces.removeAll(where: { $0.id == space.id })
        
        if activeSpaceId == space.id {
            activeSpaceId = spaces.first!.id
            activeTabId = tabs.first(where: { $0.spaceId == activeSpaceId && !$0.isPinned && !$0.isFavorite })?.id ?? openTabs.first?.id
        }
        save()
    }
    
    public func replaceSpacesAndTabs(newSpaces: [Space], newTabs: [Tab]) {
        self.spaces = newSpaces
        if let first = newSpaces.first {
            self.activeSpaceId = first.id
        }
        self.tabs = newTabs
        if let firstTab = newTabs.first(where: { $0.spaceId == self.activeSpaceId }) {
            self.activeTabId = firstTab.id
        } else {
            self.activeTabId = newTabs.first?.id
        }
        save()
    }
    
    // MARK: - Folder Management
    
    /// Return all folders configured for a specific space (including any legacy folders)
    public func folders(for spaceId: UUID) -> [ZenFolder] {
        var result = folders.filter { $0.spaceId == spaceId }
        let existingNames = Set(result.map { $0.name })
        let pinned = pinnedTabs(for: spaceId)
        let legacyNames = Set(pinned.compactMap { $0.folder?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        for name in legacyNames where !existingNames.contains(name) {
            let f = ZenFolder(name: name, iconName: nil, spaceId: spaceId)
            result.append(f)
        }
        return result.sorted(by: { $0.createdAt < $1.createdAt })
    }
    
    public func folderNames(for spaceId: UUID) -> [String] {
        folders(for: spaceId).map { $0.name }
    }
    
    /// Pinned tabs for a space, grouped by folder (nil = without folder)
    public func pinnedTabsByFolder(for spaceId: UUID) -> [(folder: ZenFolder?, tabs: [Tab])] {
        let allPinned = pinnedTabs(for: spaceId)
        var result: [(folder: ZenFolder?, tabs: [Tab])] = []
        
        // Pinned without folder first
        let rootPinned = allPinned.filter { $0.folder == nil || $0.folder?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true }
        if !rootPinned.isEmpty {
            result.append((folder: nil, tabs: rootPinned))
        }
        
        // Group by folder
        let spaceFolders = folders(for: spaceId)
        for folder in spaceFolders {
            let folderTabs = allPinned.filter { $0.folder == folder.name }
            result.append((folder: folder, tabs: folderTabs))
        }
        
        return result
    }
    
    @discardableResult
    public func createFolder(name: String, iconName: String? = nil, spaceId: UUID) -> ZenFolder {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newFolder = ZenFolder(name: cleanName.isEmpty ? "Dossier" : cleanName, iconName: iconName, spaceId: spaceId)
        folders.append(newFolder)
        save()
        return newFolder
    }
    
    @discardableResult
    public func updateFolder(id: UUID, newName: String, newIconName: String?) -> ZenFolder? {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return nil }
        let oldName = folders[idx].name
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = cleanName.isEmpty ? oldName : cleanName
        
        folders[idx].name = resolvedName
        folders[idx].iconName = newIconName
        
        if oldName != resolvedName {
            for i in 0..<tabs.count {
                if tabs[i].spaceId == folders[idx].spaceId && tabs[i].folder == oldName {
                    tabs[i].folder = resolvedName
                }
            }
        }
        save()
        return folders[idx]
    }
    
    public func deleteFolder(id: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        let removed = folders.remove(at: idx)
        for i in 0..<tabs.count {
            if tabs[i].spaceId == removed.spaceId && tabs[i].folder == removed.name {
                tabs[i].folder = nil
            }
        }
        save()
    }
    
    /// Pin a tab with an optional folder
    public func pinTab(_ tabId: UUID, folder: String? = nil) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            let wasAlreadyPinnedOrPreviouslyPinned = tabs[idx].isPinned || tabs[idx].wasPreviouslyPinned
            tabs[idx].isPinned = true
            tabs[idx].wasPreviouslyPinned = true
            tabs[idx].folder = folder?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? folder : nil
            save()
            if !wasAlreadyPinnedOrPreviouslyPinned {
                shortenPinnedTabTitleIfNeeded(tabId: tabId)
            }
        }
    }
    
    /// Adds and pins a new tab with an optional folder, triggering Apple Intelligence title shortening if available.
    @discardableResult
    public func addPinnedTab(
        url: URL,
        title: String,
        spaceId: UUID,
        folder: String? = nil
    ) -> Tab {
        let pinnedTab = Tab(
            url: url,
            title: title,
            spaceId: spaceId,
            isPinned: true,
            isFavorite: false,
            folder: folder?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? folder : nil,
            wasPreviouslyPinned: true
        )
        tabs.append(pinnedTab)
        save()
        shortenPinnedTabTitleIfNeeded(tabId: pinnedTab.id)
        return pinnedTab
    }
    
    /// Assign or change folder for a pinned tab
    public func setFolder(for tabId: UUID, folder: String?) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[idx].folder = folder?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? folder : nil
            save()
        }
    }
    
    // MARK: - Tab Actions
    
    @discardableResult
    public func openNewTab(
        url: URL? = nil,
        spaceId: UUID? = nil,
        isPrivate: Bool = false
    ) -> Tab {
        let targetSpace = spaceId ?? activeSpaceId
        let resolvedURL = url ?? SearchEngineManager.shared.config.selectedType.homeURL
        let newTab = Tab(url: resolvedURL, spaceId: targetSpace, isPrivate: isPrivate)
        tabs.append(newTab)
        activeTabId = newTab.id
        save()
        return newTab
    }
    
    public func selectTab(_ tab: Tab) {
        activeTabId = tab.id
        if tab.spaceId != activeSpaceId {
            activeSpaceId = tab.spaceId
            defaults.set(tab.spaceId.uuidString, forKey: activeSpaceKey)
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
    
    public func updateTab(id: UUID, url: URL?, title: String?) {
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            if let url = url { tabs[idx].url = url }
            if let title = title { tabs[idx].title = title }
            tabs[idx].lastAccessedAt = Date()
            save()
        }
    }
    
    public func updateActiveTab(url: URL?, title: String?) {
        guard let activeId = activeTabId else { return }
        updateTab(id: activeId, url: url, title: title)
    }
    
    public func togglePin(tabId: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            let wasAlreadyPinnedOrPreviouslyPinned = tabs[idx].isPinned || tabs[idx].wasPreviouslyPinned
            tabs[idx].isPinned.toggle()
            if !tabs[idx].isPinned {
                tabs[idx].folder = nil
            } else {
                tabs[idx].wasPreviouslyPinned = true
                if !wasAlreadyPinnedOrPreviouslyPinned {
                    shortenPinnedTabTitleIfNeeded(tabId: tabId)
                }
            }
            save()
        }
    }
    
    public func moveTabToSpace(tabId: UUID, toSpaceId: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[idx].spaceId = toSpaceId
            tabs[idx].folder = nil
            save()
        }
    }
    
    public func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closedTab = tabs.remove(at: idx)
        
        if activeTabId == id {
            if closedTab.isPrivate {
                let p = privateTabs()
                activeTabId = p.first?.id ?? openTabs.first?.id
            } else {
                let currentOpen = openTabs
                if let nextTab = currentOpen.first {
                    activeTabId = nextTab.id
                } else {
                    activeTabId = nil
                }
            }
        }
        save()
    }
    
    public func closeTab(tabId: UUID) {
        closeTab(id: tabId)
    }
    
    public func closeAllTabsInActiveSpace() {
        let spaceId = activeSpaceId
        tabs.removeAll(where: { $0.spaceId == spaceId && !$0.isPinned })
        let remaining = activeTabs(for: spaceId)
        if let first = remaining.first {
            activeTabId = first.id
        } else {
            activeTabId = openTabs.first?.id
        }
        save()
    }
    
    // MARK: - Tab Categories & Queries
    
    public enum TabZone: String, CaseIterable {
        case favorite
        case pinned
        case normal
    }

    public func favoriteTabs(for space: Space) -> [Tab] {
        tabs.filter { $0.isFavorite && !$0.isArchived && !$0.isPrivate && ($0.profileId == space.profileId || ($0.profileId == nil && $0.spaceId == space.id)) }
    }

    public func favoriteTabs(for profileId: String) -> [Tab] {
        tabs.filter { $0.isFavorite && !$0.isArchived && !$0.isPrivate && ($0.profileId == profileId || $0.profileId == nil) }
    }

    public func pinnedTabs(for spaceId: UUID) -> [Tab] {
        tabs.filter { $0.spaceId == spaceId && $0.isPinned && !$0.isFavorite && !$0.isArchived && !$0.isPrivate }
    }

    public func normalTabs(for spaceId: UUID) -> [Tab] {
        tabs.filter { $0.spaceId == spaceId && !$0.isPinned && !$0.isFavorite && !$0.isArchived && !$0.isPrivate }
    }

    public func privateTabs() -> [Tab] {
        tabs.filter { $0.isPrivate && !$0.isArchived }
    }

    public func activeTabs(for spaceId: UUID) -> [Tab] {
        let space = spaces.first(where: { $0.id == spaceId })
        let favs = space != nil ? favoriteTabs(for: space!) : []
        return favs + pinnedTabs(for: spaceId) + normalTabs(for: spaceId)
    }
    
    public func unpinnedTabs(for spaceId: UUID) -> [Tab] {
        normalTabs(for: spaceId)
    }
    
    public func todayTabs(for spaceId: UUID) -> [Tab] {
        normalTabs(for: spaceId)
    }

    public func moveTabToZone(tabId: UUID, to zone: TabZone, inSpace space: Space, folder: String? = nil) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        switch zone {
        case .favorite:
            tabs[idx].isFavorite = true
            tabs[idx].isPinned = false
            tabs[idx].folder = nil
            tabs[idx].profileId = space.profileId
        case .pinned:
            let wasAlreadyPinnedOrPreviouslyPinned = tabs[idx].isPinned || tabs[idx].wasPreviouslyPinned
            tabs[idx].isFavorite = false
            tabs[idx].isPinned = true
            tabs[idx].wasPreviouslyPinned = true
            tabs[idx].spaceId = space.id
            tabs[idx].folder = folder
            save()
            if !wasAlreadyPinnedOrPreviouslyPinned {
                shortenPinnedTabTitleIfNeeded(tabId: tabId)
            }
            return
        case .normal:
            tabs[idx].isFavorite = false
            tabs[idx].isPinned = false
            tabs[idx].folder = nil
            tabs[idx].spaceId = space.id
        }
        save()
    }

    public func toggleFavorite(tabId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].isFavorite.toggle()
        if tabs[idx].isFavorite {
            tabs[idx].isPinned = false
            tabs[idx].folder = nil
            tabs[idx].profileId = activeSpace.profileId
        }
        save()
    }

    public func reorderFavorites(for profileId: String, from source: IndexSet, to destination: Int) {
        var favs = tabs.filter { $0.isFavorite && ($0.profileId == profileId || $0.profileId == nil) }
        favs.move(fromOffsets: source, toOffset: destination)
        let nonFavs = tabs.filter { !$0.isFavorite || ($0.profileId != profileId && $0.profileId != nil) }
        self.tabs = favs + nonFavs
        save()
    }
    
    /// The single global stack of currently open tabs (independent of spaces, subject to auto-archiving)
    public var openTabs: [Tab] {
        tabs.filter { !$0.isPinned && !$0.isFavorite && !$0.isArchived && !$0.isPrivate }
    }
    
    public var activeTab: Tab? {
        if let activeId = activeTabId, let tab = tabs.first(where: { $0.id == activeId }) {
            return tab
        }
        return openTabs.first
    }
    
    /// Opens or switches to a link tapped from a space's bank of links
    public func openLinkFromSpace(tab: Tab) {
        if let existing = openTabs.first(where: { $0.url == tab.url }) {
            selectTab(existing)
        } else {
            let newTab = Tab(
                url: tab.url,
                title: tab.title,
                faviconURL: tab.faviconURL,
                spaceId: activeSpaceId,
                isPinned: false,
                isFavorite: false,
                pageZoom: tab.pageZoom,
                isDesktopMode: tab.isDesktopMode,
                isPrivate: false
            )
            tabs.append(newTab)
            activeTabId = newTab.id
            touchTab(newTab.id)
            save()
        }
    }
    
    /// Modifies the active tab's URL directly without creating a new tab
    public func updateCurrentTabURL(url: URL, title: String? = nil) {
        guard let activeId = activeTabId, let idx = tabs.firstIndex(where: { $0.id == activeId }) else { return }
        tabs[idx].url = url
        if let title = title {
            tabs[idx].title = title
        }
        tabs[idx].lastAccessedAt = Date()
        save()
    }
    
    // MARK: - Automatic Archiving
    
    public func performAutoArchiveCheck(policy: AutoArchivePolicy? = nil) {
        let activePolicy: AutoArchivePolicy
        if let policy = policy {
            activePolicy = policy
        } else {
            let policyRaw = UserDefaults.standard.string(forKey: "auto_archive_policy") ?? AutoArchivePolicy.twentyFourHours.rawValue
            activePolicy = AutoArchivePolicy(rawValue: policyRaw) ?? .twentyFourHours
        }
        
        guard let threshold = activePolicy.timeInterval, threshold > 0 else { return }
        
        let now = Date()
        var tabsToArchive: [Tab] = []
        
        tabs.removeAll { tab in
            if !tab.isPinned && !tab.isFavorite && !tab.isPrivate && now.timeIntervalSince(tab.lastAccessedAt) > threshold {
                var archived = tab
                archived.isArchived = true
                archived.archivedAt = now
                tabsToArchive.append(archived)
                return true
            }
            return false
        }
        
        if !tabsToArchive.isEmpty {
            archivedTabs.append(contentsOf: tabsToArchive)
            if let activeId = activeTabId, tabsToArchive.contains(where: { $0.id == activeId }) {
                let currentSpaceRemaining = activeTabs(for: activeSpaceId)
                self.activeTabId = currentSpaceRemaining.first?.id ?? openTabs.first?.id
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
    
    // MARK: - Apple Intelligence Pinned Tab Renaming
    
    /// Shortens a pinned tab's title asynchronously in the background using Apple Intelligence when available.
    /// If Apple Intelligence is unavailable or auto-renaming is disabled in Settings, the default title remains unchanged.
    public func shortenPinnedTabTitleIfNeeded(tabId: UUID) {
        guard PinnedTabTitleSummarizer.shared.isAutoRenameEnabled else { return }
        guard PinnedTabTitleSummarizer.shared.isAvailable else { return }
        guard let tab = tabs.first(where: { $0.id == tabId }), tab.isPinned else { return }
        
        let originalTitle = tab.title
        let url = tab.url
        
        Task {
            let shortened = await Task.detached(priority: .utility) {
                await PinnedTabTitleSummarizer.shared.shortenTitle(title: originalTitle, url: url)
            }.value
            
            guard !shortened.isEmpty, shortened != originalTitle else { return }
            
            if let idx = self.tabs.firstIndex(where: { $0.id == tabId }), self.tabs[idx].isPinned {
                if self.tabs[idx].title == originalTitle {
                    self.tabs[idx].title = shortened
                    self.save()
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        let persistentTabs = tabs.filter { !$0.isPrivate }
        let storage = defaults
        
        if let tabsData = try? JSONEncoder().encode(persistentTabs) {
            storage.set(tabsData, forKey: tabsKey)
            if storage !== UserDefaults.standard {
                UserDefaults.standard.set(tabsData, forKey: tabsKey)
            }
        }
        if let spacesData = try? JSONEncoder().encode(spaces) {
            storage.set(spacesData, forKey: spacesKey)
            if storage !== UserDefaults.standard {
                UserDefaults.standard.set(spacesData, forKey: spacesKey)
            }
        }
        if let foldersData = try? JSONEncoder().encode(folders) {
            storage.set(foldersData, forKey: foldersKey)
            if storage !== UserDefaults.standard {
                UserDefaults.standard.set(foldersData, forKey: foldersKey)
            }
        }
        if let archivedData = try? JSONEncoder().encode(archivedTabs) {
            storage.set(archivedData, forKey: archivedTabsKey)
            if storage !== UserDefaults.standard {
                UserDefaults.standard.set(archivedData, forKey: archivedTabsKey)
            }
        }
    }
}

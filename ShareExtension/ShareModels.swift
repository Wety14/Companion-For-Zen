import Foundation

// MARK: - Lightweight Space Model for Share Extension

public struct ShareSpace: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var themeColorHex: String
    public var iconName: String
    public var profileId: String
    public var order: Int
    public var gradientColorsHex: [String]
    
    public var colorHex: String {
        get { themeColorHex }
        set { themeColorHex = newValue }
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        themeColorHex: String = "#537CF7",
        iconName: String = "folder",
        profileId: String = "Personnel",
        order: Int = 0,
        gradientColorsHex: [String] = ["#537CF7", "#F27F59", "#CBF259"]
    ) {
        self.id = id
        self.name = name
        self.themeColorHex = themeColorHex
        self.iconName = iconName
        self.profileId = profileId
        self.order = order
        self.gradientColorsHex = gradientColorsHex
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, themeColorHex, colorHex, iconName, profileId, order, gradientColorsHex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let primary = try container.decodeIfPresent(String.self, forKey: .themeColorHex)
            ?? container.decodeIfPresent(String.self, forKey: .colorHex)
            ?? "#537CF7"
        themeColorHex = primary
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "folder"
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId) ?? "Personnel"
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        if let g = try container.decodeIfPresent([String].self, forKey: .gradientColorsHex), g.count >= 2 {
            gradientColorsHex = g
        } else {
            gradientColorsHex = [primary, "#3B82F6"]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(themeColorHex, forKey: .themeColorHex)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(order, forKey: .order)
        try container.encode(gradientColorsHex, forKey: .gradientColorsHex)
    }
    
    public static var defaultSpaces: [ShareSpace] {
        [
            ShareSpace(name: "Personnel", themeColorHex: "#537CF7", iconName: "person.fill", order: 0, gradientColorsHex: ["#537CF7", "#F27F59", "#CBF259"]),
            ShareSpace(name: "Travail", themeColorHex: "#F76F53", iconName: "briefcase.fill", order: 1, gradientColorsHex: ["#F76F53", "#59F2BF", "#598BF2"]),
            ShareSpace(name: "Détente", themeColorHex: "#2A9D8F", iconName: "cup.and.saucer.fill", order: 2, gradientColorsHex: ["#2A9D8F", "#B53083", "#B56330"])
        ]
    }
}

// MARK: - Lightweight Tab Model for Share Extension

public struct ShareTab: Identifiable, Codable {
    public let id: UUID
    public var url: URL
    public var title: String
    public var spaceId: UUID
    public var isPinned: Bool
    public var isFavorite: Bool
    public var profileId: String?
    public var isArchived: Bool
    public var lastAccessedAt: Date
    public var createdAt: Date
    public var isPrivate: Bool
    public var folder: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String = "",
        spaceId: UUID,
        isPinned: Bool = true,
        isFavorite: Bool = false,
        profileId: String? = nil,
        isArchived: Bool = false,
        lastAccessedAt: Date = Date(),
        createdAt: Date = Date(),
        isPrivate: Bool = false,
        folder: String? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.spaceId = spaceId
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.profileId = profileId
        self.isArchived = isArchived
        self.lastAccessedAt = lastAccessedAt
        self.createdAt = createdAt
        self.isPrivate = isPrivate
        self.folder = folder
    }
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, spaceId, isPinned, isFavorite, profileId, isArchived, lastAccessedAt, createdAt, isPrivate, folder
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        spaceId = try container.decode(UUID.self, forKey: .spaceId)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        lastAccessedAt = try container.decode(Date.self, forKey: .lastAccessedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        folder = try container.decodeIfPresent(String.self, forKey: .folder)
    }
}

// MARK: - Share Data Manager

public final class ShareDataManager {
    public static let shared = ShareDataManager()
    public static let appGroupId = "group.app.zen-browser.companion"
    
    private let spacesKey = "companion_zen_spaces"
    private let tabsKey = "companion_zen_tabs"
    private let activeSpaceKey = "companion_zen_active_space"
    
    public static let isAppGroupAvailable: Bool = {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return false
        }
        let testFile = containerURL.appendingPathComponent(".zen_share_check")
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
        ShareDataManager.safeDefaults
    }
    
    public func loadSpaces() -> [ShareSpace] {
        let storage = defaults
        if let data = storage.data(forKey: spacesKey),
           let saved = try? JSONDecoder().decode([ShareSpace].self, from: data),
           !saved.isEmpty {
            return saved.sorted(by: { $0.order < $1.order })
        }
        
        if let data = UserDefaults.standard.data(forKey: spacesKey),
           let saved = try? JSONDecoder().decode([ShareSpace].self, from: data),
           !saved.isEmpty {
            return saved.sorted(by: { $0.order < $1.order })
        }
        
        return ShareSpace.defaultSpaces
    }
    
    public func loadTabs() -> [ShareTab] {
        let storage = defaults
        if let data = storage.data(forKey: tabsKey),
           let saved = try? JSONDecoder().decode([ShareTab].self, from: data) {
            return saved
        }
        
        if let data = UserDefaults.standard.data(forKey: tabsKey),
           let saved = try? JSONDecoder().decode([ShareTab].self, from: data) {
            return saved
        }
        
        return []
    }
    
    private let foldersKey = "companion_zen_folders"
    
    public func loadZenFolders(for spaceId: UUID) -> [ZenFolder] {
        var folders: [ZenFolder] = []
        if let data = defaults.data(forKey: foldersKey),
           let saved = try? JSONDecoder().decode([ZenFolder].self, from: data) {
            folders = saved.filter { $0.spaceId == spaceId }
        }
        
        // Also merge any existing folder names from pinned tabs if not present
        let existingNames = Set(folders.map { $0.name })
        let legacyNames = loadFolders(for: spaceId)
        for name in legacyNames where !existingNames.contains(name) {
            folders.append(ZenFolder(name: name, iconName: nil, spaceId: spaceId))
        }
        
        return folders.sorted(by: { $0.createdAt < $1.createdAt })
    }
    
    public func createFolder(name: String, iconName: String?, spaceId: UUID) -> ZenFolder {
        var allFolders: [ZenFolder] = []
        if let data = defaults.data(forKey: foldersKey),
           let saved = try? JSONDecoder().decode([ZenFolder].self, from: data) {
            allFolders = saved
        }
        let newFolder = ZenFolder(name: name, iconName: iconName, spaceId: spaceId)
        allFolders.append(newFolder)
        if let encoded = try? JSONEncoder().encode(allFolders) {
            defaults.set(encoded, forKey: foldersKey)
            if defaults !== UserDefaults.standard {
                UserDefaults.standard.set(encoded, forKey: foldersKey)
            }
        }
        return newFolder
    }

    public func loadFolders(for spaceId: UUID) -> [String] {
        let tabs = loadTabs()
        let folders = tabs
            .filter { $0.spaceId == spaceId && $0.isPinned }
            .compactMap { $0.folder?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(folders)).sorted()
    }
    
    public func saveSharedTab(
        url: URL,
        title: String,
        spaceId: UUID,
        isPinned: Bool,
        isFavorite: Bool,
        profileId: String? = nil,
        folder: String? = nil
    ) {
        var existingTabs = loadTabs()
        let cleanFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newTab = ShareTab(
            url: url,
            title: title.isEmpty ? (url.host ?? "Lien partagé") : title,
            spaceId: spaceId,
            isPinned: isPinned,
            isFavorite: isFavorite,
            profileId: profileId,
            folder: (cleanFolder?.isEmpty == true) ? nil : cleanFolder
        )
        
        existingTabs.append(newTab)
        
        if let encoded = try? JSONEncoder().encode(existingTabs) {
            defaults.set(encoded, forKey: tabsKey)
            if defaults !== UserDefaults.standard {
                UserDefaults.standard.set(encoded, forKey: tabsKey)
            }
        }
    }

    public func pinTab(url: URL, title: String, spaceId: UUID, folder: String?) {
        saveSharedTab(url: url, title: title, spaceId: spaceId, isPinned: true, isFavorite: false, folder: folder)
    }
}

/// Represents a folder used to organize pinned tabs within a space.
public struct ZenFolder: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var iconName: String?
    public var spaceId: UUID
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        spaceId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.spaceId = spaceId
        self.createdAt = createdAt
    }
}


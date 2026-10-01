import Foundation

/// Represents a single browser tab.
/// Structured as a pure Codable model for clean architecture and 1:1 portability to Kotlin data class on Android.
public struct Tab: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var url: URL
    public var title: String
    public var faviconURL: URL?
    public var spaceId: UUID
    public var isPinned: Bool
    public var isFavorite: Bool
    public var profileId: String?
    public var folder: String?
    public var createdAt: Date
    public var lastAccessedAt: Date
    public var isArchived: Bool
    public var archivedAt: Date?
    public var pageZoom: Double
    public var isDesktopMode: Bool
    public var isPrivate: Bool
    public var wasPreviouslyPinned: Bool
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String = "Nouvel onglet",
        faviconURL: URL? = nil,
        spaceId: UUID,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        profileId: String? = nil,
        folder: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        pageZoom: Double = 1.0,
        isDesktopMode: Bool = false,
        isPrivate: Bool = false,
        wasPreviouslyPinned: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.spaceId = spaceId
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.profileId = profileId
        self.folder = folder
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.pageZoom = pageZoom
        self.isDesktopMode = isDesktopMode
        self.isPrivate = isPrivate
        self.wasPreviouslyPinned = wasPreviouslyPinned || isPinned
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, url, title, faviconURL, spaceId, isPinned, isFavorite, profileId, folder, createdAt, lastAccessedAt, isArchived, archivedAt, pageZoom, isDesktopMode, isPrivate, wasPreviouslyPinned
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        faviconURL = try container.decodeIfPresent(URL.self, forKey: .faviconURL)
        spaceId = try container.decode(UUID.self, forKey: .spaceId)
        let decodedIsPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isPinned = decodedIsPinned
        wasPreviouslyPinned = try container.decodeIfPresent(Bool.self, forKey: .wasPreviouslyPinned) ?? decodedIsPinned
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        profileId = try container.decodeIfPresent(String.self, forKey: .profileId)
        folder = try container.decodeIfPresent(String.self, forKey: .folder)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .lastAccessedAt) ?? Date()
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        pageZoom = try container.decodeIfPresent(Double.self, forKey: .pageZoom) ?? 1.0
        isDesktopMode = try container.decodeIfPresent(Bool.self, forKey: .isDesktopMode) ?? false
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
    }
    
    /// Display-friendly host or search query
    public var displayHost: String {
        if url.scheme == "about" || url.absoluteString == "about:blank" {
            return "Accueil"
        }
        return url.host ?? url.absoluteString
    }
    
    /// Returns the tab favicon URL or a high-res favicon service URL based on host domain.
    public var resolvedFaviconURL: URL? {
        if let fav = faviconURL { return fav }
        guard let host = url.host, !host.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }
    
    /// Shortened domain name without 'www.' (e.g. netflix.com)
    public var shortDomain: String {
        guard let host = url.host, !host.isEmpty else {
            return displayHost
        }
        var cleaned = host.lowercased()
        if cleaned.hasPrefix("www.") {
            cleaned = String(cleaned.dropFirst(4))
        }
        return cleaned
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


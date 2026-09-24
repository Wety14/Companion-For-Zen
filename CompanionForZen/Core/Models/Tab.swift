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
    public var createdAt: Date
    public var lastAccessedAt: Date
    public var isArchived: Bool
    public var archivedAt: Date?
    public var pageZoom: Double
    public var isDesktopMode: Bool
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String = "Nouvel onglet",
        faviconURL: URL? = nil,
        spaceId: UUID,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        pageZoom: Double = 1.0,
        isDesktopMode: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.spaceId = spaceId
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.pageZoom = pageZoom
        self.isDesktopMode = isDesktopMode
    }
    
    /// Display-friendly host or search query
    public var displayHost: String {
        if url.scheme == "about" || url.absoluteString == "about:blank" {
            return "Accueil"
        }
        return url.host ?? url.absoluteString
    }
}

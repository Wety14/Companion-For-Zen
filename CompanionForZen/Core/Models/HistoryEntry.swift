import Foundation

/// History record of visited web pages.
public struct HistoryEntry: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var visitedAt: Date
    public var visitCount: Int
    
    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        visitedAt: Date = Date(),
        visitCount: Int = 1
    ) {
        self.id = id
        self.url = url
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (url.host ?? url.absoluteString) : title
        self.visitedAt = visitedAt
        self.visitCount = visitCount
    }
}

/// Bookmark record for saved web pages.
public struct Bookmark: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var url: URL
    public var folder: String
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        folder: String = "Favoris",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folder = folder
        self.createdAt = createdAt
    }
}

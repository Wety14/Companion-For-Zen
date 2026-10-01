import Foundation

public enum DownloadState: String, Codable, Hashable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
}

/// Downloaded or active download task item.
public struct DownloadItem: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let originalURL: URL
    public var destinationFileURL: URL?
    public var filename: String
    public var totalBytes: Int64
    public var receivedBytes: Int64
    public var state: DownloadState
    public var mimeType: String?
    public var createdAt: Date
    public var completedAt: Date?
    
    public init(
        id: UUID = UUID(),
        originalURL: URL,
        destinationFileURL: URL? = nil,
        filename: String,
        totalBytes: Int64 = 0,
        receivedBytes: Int64 = 0,
        state: DownloadState = .pending,
        mimeType: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.originalURL = originalURL
        self.destinationFileURL = destinationFileURL
        self.filename = filename
        self.totalBytes = totalBytes
        self.receivedBytes = receivedBytes
        self.state = state
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
    
    public var progress: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(receivedBytes) / Double(totalBytes)
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes > 0 ? totalBytes : receivedBytes)
    }
}

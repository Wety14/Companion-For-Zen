import Foundation
import WebKit
import Combine

/// Manages web downloads, background writing to disk, and file access.
public final class DownloadService: NSObject, ObservableObject {
    public static let shared = DownloadService()
    
    @Published public var downloads: [DownloadItem] = []
    
    private let downloadsKey = "companion_zen_downloads"
    private let downloadsDirectory: URL
    
    public override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadsDirectory = docs.appendingPathComponent("Downloads", isDirectory: true)
        
        super.init()
        
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        if let data = UserDefaults.standard.data(forKey: downloadsKey),
           let saved = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            self.downloads = saved
        }
    }
    
    public func startDownload(url: URL, suggestedFilename: String? = nil) {
        let filename = suggestedFilename ?? url.lastPathComponent
        let safeFilename = filename.isEmpty ? "download_\(Int(Date().timeIntervalSince1970))" : filename
        let destination = downloadsDirectory.appendingPathComponent(safeFilename)
        
        let item = DownloadItem(
            originalURL: url,
            destinationFileURL: destination,
            filename: safeFilename,
            state: .downloading
        )
        downloads.insert(item, at: 0)
        save()
        
        let itemId = item.id
        
        // Asynchronous URLSession download
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let idx = self.downloads.firstIndex(where: { $0.id == itemId }) else { return }
                
                if let tempURL = tempURL, error == nil {
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                        
                        let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
                        let size = attrs[.size] as? Int64 ?? 0
                        
                        self.downloads[idx].state = .completed
                        self.downloads[idx].completedAt = Date()
                        self.downloads[idx].totalBytes = size
                        self.downloads[idx].receivedBytes = size
                        self.downloads[idx].destinationFileURL = destination
                    } catch {
                        self.downloads[idx].state = .failed
                    }
                } else {
                    self.downloads[idx].state = .failed
                }
                self.save()
            }
        }
        task.resume()
    }
    
    public func deleteDownload(_ item: DownloadItem) {
        if let fileURL = item.destinationFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        downloads.removeAll(where: { $0.id == item.id })
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: downloadsKey)
        }
    }
}

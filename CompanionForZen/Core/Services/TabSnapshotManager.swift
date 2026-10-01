import UIKit
import SwiftUI
import Combine

/// Manages high-performance in-memory and disk caching of real tab content snapshots.
public final class TabSnapshotManager: ObservableObject {
    public static let shared = TabSnapshotManager()
    
    @Published public private(set) var updateCounter: Int = 0
    
    private let cache = NSCache<NSUUID, UIImage>()
    private let diskDirectory: URL
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "app.zen-browser.companion.snapshots", qos: .utility)
    
    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskDirectory = caches.appendingPathComponent("TabSnapshots", isDirectory: true)
        try? fileManager.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
        
        cache.countLimit = 30
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max in memory
    }
    
    /// Returns the cached snapshot image for a tab if available.
    public func snapshot(for tabId: UUID) -> UIImage? {
        let key = tabId as NSUUID
        if let memoryImage = cache.object(forKey: key) {
            return memoryImage
        }
        
        let fileURL = diskDirectory.appendingPathComponent("\(tabId.uuidString).jpg")
        if let data = try? Data(contentsOf: fileURL), let diskImage = UIImage(data: data) {
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        return nil
    }
    
    /// Saves a snapshot for a tab, updating memory cache immediately and saving to disk asynchronously.
    public func saveSnapshot(_ image: UIImage, for tabId: UUID) {
        // Optimize image size for tab cards to conserve memory and disk
        let targetWidth: CGFloat = 600
        let scale = min(1.0, targetWidth / max(image.size.width, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        let key = tabId as NSUUID
        cache.setObject(resizedImage, forKey: key)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateCounter += 1
        }
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskDirectory.appendingPathComponent("\(tabId.uuidString).jpg")
            if let jpegData = resizedImage.jpegData(compressionQuality: 0.75) {
                try? jpegData.write(to: fileURL, options: .atomic)
            }
        }
    }
    
    /// Removes a snapshot from both memory and disk.
    public func removeSnapshot(for tabId: UUID) {
        let key = tabId as NSUUID
        cache.removeObject(forKey: key)
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskDirectory.appendingPathComponent("\(tabId.uuidString).jpg")
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
}

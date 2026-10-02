import Foundation
import WebKit
import Combine
import SwiftUI

/// Information about a download awaiting user permission
public struct PendingDownload: Identifiable {
    public let id = UUID()
    public let url: URL
    public let filename: String
    
    public init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
    }
}

/// Manages web downloads, background writing to disk, and file access.
public final class DownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = DownloadService()
    
    @Published public var downloads: [DownloadItem] = []
    @Published public var pendingDownload: PendingDownload?
    @Published public var isDownloading: Bool = false
    @Published public var activeProgress: Double = 0.0
    @Published public var recentlyFinishedDownload: DownloadItem?
    
    private let downloadsKey = "companion_zen_downloads"
    public let downloadsDirectory: URL
    private var activeTasks: [Int: UUID] = [:]
    private var dismissTimer: Timer?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    public override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // "Zen Browser" directory in Files app ("Sur mon iPhone")
        self.downloadsDirectory = docs.appendingPathComponent("Zen Browser", isDirectory: true)
        
        super.init()
        
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        // Migrate legacy files from "Downloads" if any existed
        let legacyDownloads = docs.appendingPathComponent("Downloads", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacyDownloads.path) {
            if let files = try? FileManager.default.contentsOfDirectory(at: legacyDownloads, includingPropertiesForKeys: nil) {
                for file in files {
                    let dest = downloadsDirectory.appendingPathComponent(file.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.moveItem(at: file, to: dest)
                    }
                }
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: downloadsKey),
           let saved = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            self.downloads = saved.map { item in
                var mod = item
                if mod.state == .downloading {
                    mod.state = .failed
                }
                // Ensure destination URL points to Zen Browser directory
                if let dest = mod.destinationFileURL {
                    let updatedDest = self.downloadsDirectory.appendingPathComponent(dest.lastPathComponent)
                    mod.destinationFileURL = updatedDest
                }
                return mod
            }
        }
    }
    
    /// Sanitizes an untrusted filename to prevent Path Traversal and illegal characters
    public func sanitizeFilename(_ raw: String) -> String {
        // Strip directory path sequences (e.g. ../../)
        var clean = (raw as NSString).lastPathComponent
        // Replace directory separators and forbidden filesystem characters
        clean = clean.replacingOccurrences(of: "/", with: "_")
                     .replacingOccurrences(of: "\\", with: "_")
                     .replacingOccurrences(of: ":", with: "_")
                     .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty || clean == "." || clean == ".." {
            return "download_\(Int(Date().timeIntervalSince1970))"
        }
        return clean
    }
    
    /// Generates a safe, non-colliding destination file URL in the Zen Browser download directory
    private func uniqueDestinationURL(for filename: String) -> (destination: URL, safeName: String) {
        let sanitized = sanitizeFilename(filename)
        let ext = (sanitized as NSString).pathExtension
        let base = (sanitized as NSString).deletingPathExtension
        
        var safeName = sanitized
        var candidate = downloadsDirectory.appendingPathComponent(safeName)
        var counter = 1
        
        while FileManager.default.fileExists(atPath: candidate.path) {
            safeName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = downloadsDirectory.appendingPathComponent(safeName)
            counter += 1
        }
        
        // Ensure destination remains strictly confined within the downloads directory
        let allowedRoot = downloadsDirectory.standardizedFileURL.path
        if !candidate.standardizedFileURL.path.hasPrefix(allowedRoot) {
            let fallbackName = "download_\(Int(Date().timeIntervalSince1970))"
            return (downloadsDirectory.appendingPathComponent(fallbackName), fallbackName)
        }
        
        return (candidate, safeName)
    }

    /// Requests download confirmation from the user via dialog before starting.
    public func requestDownload(url: URL, suggestedFilename: String? = nil) {
        let rawName = suggestedFilename ?? url.lastPathComponent
        let safeFilename = sanitizeFilename(rawName)
        DispatchQueue.main.async {
            self.pendingDownload = PendingDownload(url: url, filename: safeFilename)
        }
    }
    
    /// Confirms and starts the pending download.
    public func confirmPendingDownload() {
        guard let pending = pendingDownload else { return }
        let url = pending.url
        let filename = pending.filename
        self.pendingDownload = nil
        startDownload(url: url, suggestedFilename: filename)
    }
    
    /// Cancels the pending download request.
    public func cancelPendingDownload() {
        self.pendingDownload = nil
    }
    
    /// Dismisses the recently finished download pill manually
    public func dismissRecentlyFinished() {
        dismissTimer?.invalidate()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            recentlyFinishedDownload = nil
        }
    }
    
    /// Starts downloading the file and monitors progress.
    public func startDownload(url: URL, suggestedFilename: String? = nil) {
        let rawName = suggestedFilename ?? url.lastPathComponent
        let (destination, safeFilename) = uniqueDestinationURL(for: rawName)
        
        let item = DownloadItem(
            originalURL: url,
            destinationFileURL: destination,
            filename: safeFilename,
            state: .downloading
        )
        downloads.insert(item, at: 0)
        save()
        
        let task = urlSession.downloadTask(with: url)
        activeTasks[task.taskIdentifier] = item.id
        task.resume()
        
        updateActiveProgress()
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let itemId = activeTasks[downloadTask.taskIdentifier],
              let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
        
        downloads[idx].receivedBytes = totalBytesWritten
        if totalBytesExpectedToWrite > 0 {
            downloads[idx].totalBytes = totalBytesExpectedToWrite
        }
        updateActiveProgress()
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let itemId = activeTasks[downloadTask.taskIdentifier],
              let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
        
        let preferredName = downloads[idx].filename
        let (finalDestination, finalName) = uniqueDestinationURL(for: preferredName)
        
        do {
            try FileManager.default.moveItem(at: location, to: finalDestination)
            
            let attrs = try FileManager.default.attributesOfItem(atPath: finalDestination.path)
            let size = attrs[.size] as? Int64 ?? downloads[idx].receivedBytes
            
            downloads[idx].state = .completed
            downloads[idx].completedAt = Date()
            downloads[idx].totalBytes = size
            downloads[idx].receivedBytes = size
            downloads[idx].destinationFileURL = finalDestination
            downloads[idx].filename = finalName
            
            let finishedItem = downloads[idx]
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.recentlyFinishedDownload = finishedItem
                }
                // Disappears automatically after 30 seconds
                self.dismissTimer?.invalidate()
                self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self?.recentlyFinishedDownload = nil
                    }
                }
            }
        } catch {
            downloads[idx].state = .failed
        }
        activeTasks.removeValue(forKey: downloadTask.taskIdentifier)
        save()
        updateActiveProgress()
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let itemId = activeTasks[task.taskIdentifier],
              let idx = downloads.firstIndex(where: { $0.id == itemId }) else { return }
        
        if let error = error {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                downloads[idx].state = .failed
            } else {
                downloads[idx].state = .cancelled
            }
            activeTasks.removeValue(forKey: task.taskIdentifier)
            save()
            updateActiveProgress()
        }
    }
    
    private func updateActiveProgress() {
        let active = downloads.filter { $0.state == .downloading }
        if active.isEmpty {
            if self.isDownloading {
                self.activeProgress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    if self.downloads.filter({ $0.state == .downloading }).isEmpty {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.isDownloading = false
                            self.activeProgress = 0.0
                        }
                    }
                }
            } else {
                self.isDownloading = false
                self.activeProgress = 0.0
            }
        } else {
            self.isDownloading = true
            let totalExpected = active.reduce(0 as Int64) { $0 + max($1.totalBytes, $1.receivedBytes) }
            let totalReceived = active.reduce(0 as Int64) { $0 + $1.receivedBytes }
            if totalExpected > 0 {
                self.activeProgress = min(1.0, max(0.05, Double(totalReceived) / Double(totalExpected)))
            } else {
                self.activeProgress = 0.1
            }
        }
    }
    
    public func deleteDownload(_ item: DownloadItem) {
        if let (taskIdentifier, _) = activeTasks.first(where: { $0.value == item.id }) {
            urlSession.getAllTasks { tasks in
                if let task = tasks.first(where: { $0.taskIdentifier == taskIdentifier }) {
                    task.cancel()
                }
            }
            activeTasks.removeValue(forKey: taskIdentifier)
        }
        if let fileURL = item.destinationFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if recentlyFinishedDownload?.id == item.id {
            recentlyFinishedDownload = nil
        }
        downloads.removeAll(where: { $0.id == item.id })
        save()
        updateActiveProgress()
    }
    
    public func deleteDownloads(_ itemIds: Set<UUID>) {
        for id in itemIds {
            if let item = downloads.first(where: { $0.id == id }) {
                if let (taskIdentifier, _) = activeTasks.first(where: { $0.value == item.id }) {
                    urlSession.getAllTasks { tasks in
                        if let task = tasks.first(where: { $0.taskIdentifier == taskIdentifier }) {
                            task.cancel()
                        }
                    }
                    activeTasks.removeValue(forKey: taskIdentifier)
                }
                if let fileURL = item.destinationFileURL {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
        if let rec = recentlyFinishedDownload, itemIds.contains(rec.id) {
            recentlyFinishedDownload = nil
        }
        downloads.removeAll(where: { itemIds.contains($0.id) })
        save()
        updateActiveProgress()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: downloadsKey)
        }
    }
}

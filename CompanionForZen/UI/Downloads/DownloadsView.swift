import SwiftUI
import QuickLook

public enum DownloadSortOption: String, CaseIterable, Identifiable {
    case dateDescending = "Date : Récents d'abord"
    case dateAscending = "Date : Anciens d'abord"
    case nameAscending = "Nom : A à Z"
    case nameDescending = "Nom : Z à A"
    
    public var id: String { rawValue }
}

/// Downloads list view with file progress, sharing, sorting, multi-selection, and QuickLook previewing.
public struct DownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var downloadService = DownloadService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    public var isPresentedModally: Bool = false
    
    public init(isPresentedModally: Bool = false) {
        self.isPresentedModally = isPresentedModally
    }
    
    @State private var selectedPreviewURL: URL?
    @State private var sortOption: DownloadSortOption = .dateDescending
    @State private var isSelectMode: Bool = false
    @State private var selectedItemIds = Set<UUID>()
    
    private var sortedDownloads: [DownloadItem] {
        downloadService.downloads.sorted { a, b in
            switch sortOption {
            case .dateDescending:
                let dateA = a.completedAt ?? a.createdAt
                let dateB = b.completedAt ?? b.createdAt
                return dateA > dateB
            case .dateAscending:
                let dateA = a.completedAt ?? a.createdAt
                let dateB = b.completedAt ?? b.createdAt
                return dateA < dateB
            case .nameAscending:
                return a.filename.localizedCaseInsensitiveCompare(b.filename) == .orderedAscending
            case .nameDescending:
                return a.filename.localizedCaseInsensitiveCompare(b.filename) == .orderedDescending
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if downloadService.downloads.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(String(localized: "no_downloads", bundle: .main))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedDownloads) { item in
                        let isSelected = selectedItemIds.contains(item.id)
                        
                        Button {
                            if isSelectMode {
                                Haptics.selection()
                                if isSelected {
                                    selectedItemIds.remove(item.id)
                                } else {
                                    selectedItemIds.insert(item.id)
                                }
                            } else {
                                if item.state == .completed, let fileURL = item.destinationFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                                    Haptics.light()
                                    selectedPreviewURL = fileURL
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                if isSelectMode {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundColor(isSelected ? themeManager.accentColor : .secondary)
                                        .transition(.scale.combined(with: .opacity))
                                }
                                
                                Image(systemName: iconName(for: item.filename))
                                    .font(.title2)
                                    .foregroundColor(themeManager.accentColor)
                                    .frame(width: 36)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.filename)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 8) {
                                        Text(item.formattedSize)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if item.state == .downloading {
                                            Text("downloading")
                                                .font(.caption.bold())
                                                .foregroundColor(themeManager.accentColor)
                                        } else if item.state == .completed {
                                            Text("done")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        } else if item.state == .failed {
                                            Text("failed")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    if item.state == .downloading {
                                        ProgressView(value: item.progress)
                                            .tint(themeManager.accentColor)
                                            .scaleEffect(x: 1, y: 0.6, anchor: .center)
                                    }
                                }
                                
                                Spacer()
                                
                                if !isSelectMode && item.state == .completed, let fileURL = item.destinationFileURL {
                                    Button(action: {
                                        Haptics.medium()
                                        shareFiles(urls: [fileURL])
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 15))
                                            .foregroundColor(themeManager.accentColor)
                                            .frame(width: 36, height: 36)
                                            .background(Color.primary.opacity(0.06), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !isSelectMode {
                                Button(role: .destructive) {
                                    downloadService.deleteDownload(item)
                                } label: {
                                    Label(String(localized: "delete_tab", bundle: .main), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Bottom Multi-Selection Action Bar
                if isSelectMode {
                    HStack {
                        // Batch Delete
                        Button(role: .destructive) {
                            Haptics.medium()
                            downloadService.deleteDownloads(selectedItemIds)
                            selectedItemIds.removeAll()
                            if downloadService.downloads.isEmpty {
                                isSelectMode = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text(String(format: String(localized: "delete_count_format", bundle: .main), selectedItemIds.count))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(selectedItemIds.isEmpty ? .secondary : .red)
                        }
                        .disabled(selectedItemIds.isEmpty)
                        
                        Spacer()
                        
                        // Batch Share
                        Button {
                            Haptics.medium()
                            let urls = downloadService.downloads
                                .filter { selectedItemIds.contains($0.id) }
                                .compactMap { $0.destinationFileURL }
                                .filter { FileManager.default.fileExists(atPath: $0.path) }
                            shareFiles(urls: urls)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text(String(format: String(localized: "share_count_format", bundle: .main), selectedItemIds.count))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(selectedItemIds.isEmpty ? .secondary : themeManager.accentColor)
                        }
                        .disabled(selectedItemIds.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(String(localized: "downloads", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close", bundle: .main)) {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                if !downloadService.downloads.isEmpty {
                    if isSelectMode {
                        Button(selectedItemIds.count == sortedDownloads.count ? String(localized: "deselect_all", bundle: .main) : String(localized: "select_all", bundle: .main)) {
                            Haptics.light()
                            if selectedItemIds.count == sortedDownloads.count {
                                selectedItemIds.removeAll()
                            } else {
                                selectedItemIds = Set(sortedDownloads.map(\.id))
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(themeManager.accentColor)
                    } else {
                        Menu {
                            Picker(String(localized: "sort_by", bundle: .main), selection: $sortOption) {
                                ForEach(DownloadSortOption.allCases) { opt in
                                    Text(opt.rawValue).tag(opt)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if !downloadService.downloads.isEmpty {
                    Button(isSelectMode ? String(localized: "done", bundle: .main) : String(localized: "select", bundle: .main)) {
                        Haptics.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedItemIds.removeAll()
                            }
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .quickLookPreview($selectedPreviewURL)
    }
    
    private func iconName(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "png", "jpg", "jpeg", "webp", "gif": return "photo.fill"
        case "mp4", "mov", "m4v": return "film.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "mp3", "wav", "m4a": return "music.note"
        default: return "doc.fill"
        }
    }
    
    private func shareFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        // Find topmost view controller across active scenes and sheets
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else {
            return
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

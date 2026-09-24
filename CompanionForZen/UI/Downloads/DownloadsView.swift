import SwiftUI
import QuickLook

/// Downloads list view with file progress, sharing, and previewing.
public struct DownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var downloadService = DownloadService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    @State private var selectedPreviewURL: URL?
    
    public var body: some View {
        Group {
                if downloadService.downloads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text(tr("no_downloads"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(downloadService.downloads) { item in
                            HStack(spacing: 14) {
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
                                            Text("Téléchargement...")
                                                .font(.caption.bold())
                                                .foregroundColor(themeManager.accentColor)
                                        } else if item.state == .completed {
                                            Text("Terminé")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        } else if item.state == .failed {
                                            Text("Échoué")
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
                                
                                if item.state == .completed, let fileURL = item.destinationFileURL {
                                    Button(action: {
                                        shareFile(url: fileURL)
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 15))
                                            .foregroundColor(.secondary)
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    downloadService.deleteDownload(item)
                                } label: {
                                    Label(tr("delete_tab"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(tr("downloads"))
            .navigationBarTitleDisplayMode(.inline)
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
    
    private func shareFile(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }
}

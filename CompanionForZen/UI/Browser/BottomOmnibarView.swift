import SwiftUI

/// Floating Bottom Bar inspired by Arc Search iOS layout:
/// - Left: Tab switcher button to access all tabs
/// - Center: Prominent '+' button for immediate search / new tab
/// - Right: Three dots '...' button to open Zen Tools
/// - Distraction-free: No persistent URL taking up width
/// - Top: Sleek loading bar when page is loading
/// - Above: Download progress or finished download interactive pill
public struct BottomOmnibarView: View {
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var adBlockService = AdBlockService.shared
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var downloadService = DownloadService.shared
    
    public var currentURL: URL?
    public var pageTitle: String
    public var isLoading: Bool
    public var progress: Double
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var isFastScrolling: Bool
    public var hasActiveTab: Bool
    public var isTabsOverview: Bool
    
    public var onBack: () -> Void
    public var onForward: () -> Void
    public var onReload: () -> Void
    public var onOpenSearch: () -> Void
    public var onOpenTabDrawer: () -> Void
    public var onOpenTabSwitcher: () -> Void
    public var onOpenTools: () -> Void
    public var onOpenSendTab: (() -> Void)?
    public var onShare: (() -> Void)?
    public var onOpenFinishedDownload: ((DownloadItem) -> Void)?
    
    public init(
        currentURL: URL? = nil,
        pageTitle: String = "",
        isLoading: Bool = false,
        progress: Double = 0.0,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isFastScrolling: Bool = false,
        hasActiveTab: Bool = true,
        isTabsOverview: Bool = false,
        onBack: @escaping () -> Void = {},
        onForward: @escaping () -> Void = {},
        onReload: @escaping () -> Void = {},
        onOpenSearch: @escaping () -> Void,
        onOpenTabDrawer: @escaping () -> Void,
        onOpenTabSwitcher: @escaping () -> Void = {},
        onOpenTools: @escaping () -> Void,
        onOpenSendTab: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onOpenFinishedDownload: ((DownloadItem) -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.pageTitle = pageTitle
        self.isLoading = isLoading
        self.progress = progress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isFastScrolling = isFastScrolling
        self.hasActiveTab = hasActiveTab
        self.isTabsOverview = isTabsOverview
        self.onBack = onBack
        self.onForward = onForward
        self.onReload = onReload
        self.onOpenSearch = onOpenSearch
        self.onOpenTabDrawer = onOpenTabDrawer
        self.onOpenTabSwitcher = onOpenTabSwitcher
        self.onOpenTools = onOpenTools
        self.onOpenSendTab = onOpenSendTab
        self.onShare = onShare
        self.onOpenFinishedDownload = onOpenFinishedDownload
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. Download Progress or Recently Finished banner ABOVE the '+' omnibar
            if downloadService.isDownloading {
                downloadProgressBanner
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            } else if let finished = downloadService.recentlyFinishedDownload {
                finishedDownloadBanner(finished)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
            
            // 2. Main Omnibar Bar
            omnibarBar
        }
        // Responsive size contraction during fast scrolling
        .scaleEffect(isFastScrolling ? 0.88 : 1.0)
        .opacity(isFastScrolling ? 0.70 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: isFastScrolling)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: downloadService.isDownloading)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: downloadService.recentlyFinishedDownload != nil)
        .padding(.bottom, 8)
    }
    
    // MARK: - Download Progress Banner (Above Omnibar)
    private var downloadProgressBanner: some View {
        HStack(spacing: 12) {
            // Circular progress ring with arrow
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 2.2)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.05, downloadService.activeProgress)))
                    .stroke(themeManager.accentColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: downloadService.activeProgress)
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
            }
            .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("downloading")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(downloadService.activeProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ProgressView(value: downloadService.activeProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: themeManager.accentColor))
                .frame(width: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 270)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(themeManager.accentColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - Finished Download Banner (Above Omnibar, clickable, 30s auto-dismiss)
    private func finishedDownloadBanner(_ item: DownloadItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("download_done")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Haptics.light()
                downloadService.dismissRecentlyFinished()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 280)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .contentShape(Capsule())
        .onTapGesture {
            Haptics.medium()
            onOpenFinishedDownload?(item)
            downloadService.dismissRecentlyFinished()
        }
    }
    
    // MARK: - Main Omnibar Bar
    private var omnibarBar: some View {
        VStack(spacing: 0) {
            // Sleek loading progress bar at the top edge of the pill
            if isLoading && progress < 1.0 {
                GeometryReader { geo in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, ZenDesign.zenCream],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress), height: 3)
                        .animation(.linear(duration: 0.2), value: progress)
                }
                .frame(height: 3)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            
            HStack(spacing: 0) {
                // Left: Tabs button or Desktop Spaces button
                Image(systemName: (isTabsOverview || !hasActiveTab) ? "desktopcomputer" : "square.on.square")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.primary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTabsOverview)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.medium()
                        if isTabsOverview || !hasActiveTab {
                            onOpenTabDrawer()
                        } else {
                            onOpenTabSwitcher()
                        }
                    }
                .onLongPressGesture(minimumDuration: 0.28) {
                    Haptics.heavy()
                    onOpenTabDrawer()
                }
                
                Spacer()
                
                // Center: Pure Glass '+' Button
                GlassPlusButton(
                    action: onOpenSearch,
                    accentColor: themeManager.accentColor,
                    size: 44
                )
                .frame(width: 52, height: 48)
                .contentShape(Rectangle())
                
                Spacer()
                
                // Right: Three dots '...' button (tap = Zen Tools, short hold = Send Tab panel)
                ZStack {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.light()
                    onOpenTools()
                }
                .onLongPressGesture(minimumDuration: 0.28) {
                    Haptics.success()
                    onOpenSendTab?()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(width: 250)
        .background(
            ZStack {
                // Translucent ultra-thin frosted glass (slightly transparent)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.70)
                
                // Subtle transparent tint allowing web content to shine through
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.18))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.40),
                            themeManager.accentColor.opacity(0.40),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 6)
    }
}

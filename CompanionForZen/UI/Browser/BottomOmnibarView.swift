import SwiftUI

/// Floating Bottom Bar inspired by Arc Search iOS layout:
/// - Left: Tab switcher button to access all tabs
/// - Center: Prominent '+' button for immediate search / new tab
/// - Right: Three dots '...' button to open Zen Tools
/// - Distraction-free: No persistent URL taking up width
/// - Top: Sleek loading bar when page is loading
public struct BottomOmnibarView: View {
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var adBlockService = AdBlockService.shared
    
    public var currentURL: URL?
    public var pageTitle: String
    public var isLoading: Bool
    public var progress: Double
    public var canGoBack: Bool
    public var canGoForward: Bool
    
    public var onBack: () -> Void
    public var onForward: () -> Void
    public var onReload: () -> Void
    public var onOpenSearch: () -> Void
    public var onOpenTabDrawer: () -> Void
    public var onOpenTools: () -> Void
    public var onOpenSendTab: (() -> Void)?
    public var onShare: (() -> Void)?
    
    public init(
        currentURL: URL? = nil,
        pageTitle: String = "",
        isLoading: Bool = false,
        progress: Double = 0.0,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        onBack: @escaping () -> Void = {},
        onForward: @escaping () -> Void = {},
        onReload: @escaping () -> Void = {},
        onOpenSearch: @escaping () -> Void,
        onOpenTabDrawer: @escaping () -> Void,
        onOpenTools: @escaping () -> Void,
        onOpenSendTab: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil
    ) {
        self.currentURL = currentURL
        self.pageTitle = pageTitle
        self.isLoading = isLoading
        self.progress = progress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.onBack = onBack
        self.onForward = onForward
        self.onReload = onReload
        self.onOpenSearch = onOpenSearch
        self.onOpenTabDrawer = onOpenTabDrawer
        self.onOpenTools = onOpenTools
        self.onOpenSendTab = onOpenSendTab
        self.onShare = onShare
    }
    
    public var body: some View {
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
                // Left: Tabs button with elegant overlapping tabs icon (square.on.square)
                Button(action: {
                    Haptics.medium()
                    onOpenTabDrawer()
                }) {
                    ZStack {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // Active Space Color Dot
                        Circle()
                            .fill(Color(hex: tabManager.activeSpace.themeColorHex))
                            .frame(width: 6, height: 6)
                            .offset(x: 10, y: -10)
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Center: Arc Search Prominent '+' Button
                Button(action: {
                    Haptics.medium()
                    onOpenSearch()
                }) {
                    ZStack {
                        Circle()
                            .fill(themeManager.accentColor)
                            .frame(width: 44, height: 44)
                            .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, x: 0, y: 3)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 52, height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
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
        .padding(.bottom, 8)
    }
}

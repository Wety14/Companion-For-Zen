import SwiftUI
import WebKit

/// Open Tabs Switcher matching the iOS App Switcher / Multitasking design:
/// - Horizontal scrollable carousel of open tab cards.
/// - Progressive finger-following vertical swipe-to-close on each card.
/// - Bottom left Desktop button to open the Spaces menu.
/// - Prominent '+' button to open a new tab / search.
public struct TabSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    public var onDismiss: () -> Void
    public var onSelectTab: ((Tab) -> Void)?
    public var onOpenSpacesMenu: () -> Void
    public var onOpenSearch: () -> Void
    
    @State private var closingTabIds: Set<UUID> = []
    
    public init(
        onDismiss: @escaping () -> Void = {},
        onSelectTab: ((Tab) -> Void)? = nil,
        onOpenSpacesMenu: @escaping () -> Void = {},
        onOpenSearch: @escaping () -> Void = {}
    ) {
        self.onDismiss = onDismiss
        self.onSelectTab = onSelectTab
        self.onOpenSpacesMenu = onOpenSpacesMenu
        self.onOpenSearch = onOpenSearch
    }
    
    private func handleDismiss() {
        onDismiss()
        dismiss()
    }
    
    private var openTabs: [Tab] {
        tabManager.openTabs
    }
    
    public var body: some View {
        GeometryReader { fullGeo in
            let screenWidth = max(fullGeo.size.width, 320)
            let screenHeight = max(fullGeo.size.height, 480)
            let cardWidth = max(min(screenWidth * 0.72, 310), 120)
            let cardHeight = max(min(screenHeight * 0.62, 540), 180)
            
                    ZStack {
                        // Dimmed translucent blurred background
                        Color.black.opacity(0.65)
                            .background(.ultraThinMaterial.opacity(0.85))
                            .ignoresSafeArea()
                            .onTapGesture {
                                Haptics.light()
                                handleDismiss()
                            }
                        
                        VStack(spacing: 0) {
                            // Center: Horizontal Carousel of Cards with expanded vertical sensitivity
                            if !openTabs.isEmpty {
                                ScrollViewReader { scrollProxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 20) {
                                            ForEach(openTabs) { tab in
                                                if !closingTabIds.contains(tab.id) {
                                                    AppSwitcherTabCard(
                                                        tab: tab,
                                                        cardWidth: cardWidth,
                                                        cardHeight: cardHeight,
                                                        onSelect: {
                                                            Haptics.selection()
                                                            tabManager.selectTab(tab)
                                                            onSelectTab?(tab)
                                                            handleDismiss()
                                                        },
                                                        onClose: {
                                                            closeTabWithAnimation(tab.id)
                                                        }
                                                    )
                                                    .id(tab.id)
                                                    .transition(.asymmetric(
                                                        insertion: .scale.combined(with: .opacity),
                                                        removal: .move(edge: .top).combined(with: .opacity)
                                                    ))
                                                }
                                            }
                                        }
                                        .padding(.horizontal, max((screenWidth - cardWidth) / 2, 24))
                                        .padding(.vertical, 30)
                                        .frame(minHeight: cardHeight + 60)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .onAppear {
                                        if let activeId = tabManager.activeTabId {
                                            scrollProxy.scrollTo(activeId, anchor: .center)
                                        }
                                    }
                                }
                            } else {
                                Spacer()
                            }
                            
                            // Bottom space reserve so cards sit comfortably above floating BottomOmnibarView
                            Spacer()
                                .frame(height: 75)
                        }
                    }
        }
        .onAppear {
            if tabManager.openTabs.isEmpty {
                dismiss()
            }
        }
        .onChange(of: tabManager.openTabs.count) { _, newCount in
            if newCount == 0 {
                dismiss()
            }
        }
    }
    
    private func closeTabWithAnimation(_ tabId: UUID) {
        Haptics.medium()
        let isLastTab = tabManager.openTabs.count <= 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            _ = closingTabIds.insert(tabId)
        }
        if isLastTab {
            tabManager.closeTab(id: tabId)
            closingTabIds.remove(tabId)
            dismiss()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            tabManager.closeTab(id: tabId)
            closingTabIds.remove(tabId)
            if tabManager.openTabs.isEmpty {
                dismiss()
            }
        }
    }
}

/// Live WKWebView preview for open tabs inside the Tab Switcher.
/// Embedded with user interactions disabled so swiping across cards works without capturing web touches.
private struct TabLiveWebPreview: UIViewRepresentable {
    let tab: Tab
    
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true
        
        let webView = TabWebViewManager.shared.webView(for: tab)
        webView.removeFromSuperview()
        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let webView = uiView.subviews.first(where: { $0 is WKWebView }) as? WKWebView {
            webView.isUserInteractionEnabled = false
            webView.scrollView.isScrollEnabled = false
        }
    }
}

/// Individual card inside the iOS App Switcher:
/// Live WebKit page preview for standard tabs, privacy stealth layout for private tabs.
/// Implements interactive vertical drag tracking finger 1:1 to dismiss without intercepting horizontal carousel swipes.
private struct AppSwitcherTabCard: View {
    let tab: Tab
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    // Vertical swipe-to-close state
    @State private var dragYOffset: CGFloat = 0
    @State private var isDraggingUp: Bool = false
    
    private var cardAccent: Color {
        tab.isPrivate ? .purple : themeManager.accentColor
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                if tab.isPrivate {
                    HStack(spacing: 4) {
                        Image(systemName: "eyeglasses.slash")
                            .font(.system(size: 11, weight: .bold))
                        Text(NSLocalizedString("private_browsing", comment: "Private mode label"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.85), in: Capsule())
                } else {
                    HStack(spacing: 6) {
                        TabFaviconView(tab: tab, size: 16)
                        Text(tab.title.isEmpty ? tab.shortDomain : tab.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
                
                // Close button
                Button {
                    Haptics.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Content Body: Live WebKit view preview (non-private) or privacy stealth layout (private)
            if tab.isPrivate {
                Spacer()
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.18))
                            .frame(width: 74, height: 74)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    VStack(spacing: 4) {
                        Text(tab.shortDomain.isEmpty ? "zen-browser" : tab.shortDomain)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(tab.title.isEmpty ? tab.shortDomain : tab.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                Spacer()
            } else {
                TabLiveWebPreview(tab: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: max(cardWidth, 50), height: max(cardHeight, 80))
        .background(
            ZStack {
                Color(uiColor: .systemBackground)
                    .opacity(0.85)
            }
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    Color.white.opacity(0.18),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 8,
            x: 0,
            y: 5
        )
        // Coordinated 1:1 vertical drag offset
        .offset(y: dragYOffset)
        .opacity(isDraggingUp ? max(0.2, Double(1.0 - (-dragYOffset / 350.0))) : 1.0)
        .scaleEffect(isDraggingUp ? max(0.85, 1.0 - (-dragYOffset / 1200.0)) : 1.0)
        // Tap to select tab
        .onTapGesture {
            onSelect()
        }
        // Coordinated vertical swipe-to-close gesture that doesn't capture horizontal carousel scroll
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let dx = abs(value.translation.width)
                    let dy = value.translation.height
                    
                    if !isDraggingUp {
                        // Only engage if motion is clearly vertical upwards
                        if dy < -12 && abs(dy) > dx * 1.5 {
                            isDraggingUp = true
                            dragYOffset = dy
                        }
                    } else {
                        // Once locked into upward swipe, track finger
                        dragYOffset = min(0, dy)
                    }
                }
                .onEnded { value in
                    if isDraggingUp {
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let threshold: CGFloat = -110
                        
                        if value.translation.height < threshold || velocity < -350 {
                            // Dismiss upward and close tab
                            Haptics.medium()
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragYOffset = -cardHeight - 200
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onClose()
                            }
                        } else {
                            // Spring back to center
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                dragYOffset = 0
                                isDraggingUp = false
                            }
                        }
                    } else {
                        dragYOffset = 0
                        isDraggingUp = false
                    }
                }
        )
    }
}

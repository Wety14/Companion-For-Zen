import SwiftUI

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
                                                        isActive: tab.id == tabManager.activeTabId,
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
            TabSnapshotManager.shared.removeSnapshot(for: tabId)
            closingTabIds.remove(tabId)
            dismiss()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            tabManager.closeTab(id: tabId)
            TabSnapshotManager.shared.removeSnapshot(for: tabId)
            closingTabIds.remove(tabId)
            if tabManager.openTabs.isEmpty {
                dismiss()
            }
        }
    }
}

/// Individual card inside the iOS App Switcher:
/// Implements interactive vertical drag tracking finger 1:1 to dismiss.
private struct AppSwitcherTabCard: View {
    let tab: Tab
    let isActive: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var snapshotManager = TabSnapshotManager.shared
    
    // Vertical swipe-to-close state
    @State private var dragYOffset: CGFloat = 0
    @State private var isDraggingUp: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                TabFaviconView(tab: tab, size: 18, fallbackColor: .white)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(tab.title.isEmpty ? tab.shortDomain : tab.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(tab.shortDomain)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Close button
                Button {
                    Haptics.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.55))
            
            // Web Preview Surface (Real tab rendered content)
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                
                if let image = snapshotManager.snapshot(for: tab.id) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: max(cardWidth, 50), height: max(cardHeight - 44, 50), alignment: .top)
                        .clipped()
                } else {
                    // Fallback placeholder before snapshot is ready
                    VStack(spacing: 12) {
                        TabFaviconView(tab: tab, size: 36, fallbackColor: .primary)
                        
                        Text(tab.shortDomain)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.75))
                        
                        Text(tab.title)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .lineLimit(2)
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: max(cardWidth, 50), height: max(cardHeight, 80))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isActive ? themeManager.accentColor : Color.white.opacity(0.18),
                    lineWidth: isActive ? 2.5 : 1
                )
        )
        .shadow(
            color: isActive ? themeManager.accentColor.opacity(0.4) : Color.black.opacity(0.35),
            radius: isActive ? 14 : 10,
            x: 0,
            y: 6
        )
        // Coordinated 1:1 vertical drag offset
        .offset(y: dragYOffset)
        .opacity(isDraggingUp ? max(0.2, Double(1.0 - (-dragYOffset / 350.0))) : 1.0)
        .scaleEffect(isDraggingUp ? max(0.85, 1.0 - (-dragYOffset / 1200.0)) : 1.0)
        // Tap to select tab
        .onTapGesture {
            onSelect()
        }
        // Coordinated vertical swipe-to-close gesture
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    // Only track upward gestures
                    if value.translation.height < 0 {
                        isDraggingUp = true
                        dragYOffset = value.translation.height
                    }
                }
                .onEnded { value in
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
                }
        )
    }
}

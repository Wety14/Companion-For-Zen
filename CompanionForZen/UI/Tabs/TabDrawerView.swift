import SwiftUI
import UniformTypeIdentifiers

/// Redesigned Spaces Menu / Drawer matching Zen Browser desktop aesthetics.
/// - Dynamic space gradient full-bleed backdrop.
/// - Top header displays space icon before the space name, with no profile or tab count.
/// - Decoupled from open tabs: acts as a bank of links (favorites, pinned with folders, space links).
/// - Tapping any link opens it without altering background open tabs when switching spaces.
/// - 3 zones separated purely by horizontal dividing lines (no section titles):
///   1. Favorites
///   2. Pinned (folders with custom icons/emojis)
///   3. Space Links
/// - Bottom-right floating "+" button to create a new tab (long-press for new folder).
/// - Progressive space swipe with real-time gradient blending.
/// - Space dock context menu: "Basculer sur cet espace" is hidden if already on that space.
public struct TabDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    public var onOpenSearch: (() -> Void)? = nil
    public var onSelectTab: (() -> Void)? = nil
    
    // View state
    @State private var showingArchiveSheet: Bool = false
    @State private var showingCreateFolderSheet: Bool = false
    @State private var expandedFolders: Set<String> = []
    
    // Progressive Space Swipe Transition
    private enum SwipeDirection {
        case undetermined
        case horizontal
        case vertical
    }
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingTransition: Bool = false
    @State private var swipeDirection: SwipeDirection = .undetermined
    @State private var showingCreateSpaceSheet: Bool = false
    @State private var hasTriggeredCreateSpaceHaptic: Bool = false
    @State private var showingDownloadsSheet: Bool = false
    @State private var hasTriggeredDownloadsHaptic: Bool = false
    
    // Native Drop Targeting States
    @State private var isTargetedFavorites: Bool = false
    @State private var isTargetedPinned: Bool = false
    @State private var isTargetedNormal: Bool = false
    @State private var hoveredDockSpaceId: UUID? = nil
    
    // Space & Folder Editing
    @State private var spaceToEdit: Space? = nil
    @State private var editingFolder: ZenFolder? = nil
    
    // Interactive Space Dock Drag-to-Reorder State
    @State private var draggedSpaceId: UUID? = nil
    @State private var draggedSpaceOffset: CGSize = .zero
    @State private var prospectiveTargetIndex: Int? = nil
    
    public init(
        onOpenSearch: (() -> Void)? = nil,
        onSelectTab: (() -> Void)? = nil
    ) {
        self.onOpenSearch = onOpenSearch
        self.onSelectTab = onSelectTab
    }
    
    private var sortedSpaces: [Space] {
        tabManager.spaces.sorted(by: { $0.order < $1.order })
    }
    
    private var currentSpace: Space {
        tabManager.activeSpace
    }
    
    private var currentSpaceIndex: Int {
        sortedSpaces.firstIndex(where: { $0.id == currentSpace.id }) ?? 0
    }
    
    // Continuous space navigation (ordered linearly without circular wrap)
    private var swipeProgressData: (target: Space?, progress: Double) {
        let count = sortedSpaces.count
        guard count > 0, dragOffset != 0 else { return (nil, 0.0) }
        let screenWidth = max(UIScreen.main.bounds.width, 320)
        
        if dragOffset < 0 {
            // Swiping Left -> Towards rightward space
            let nextIndex = currentSpaceIndex + 1
            if nextIndex < count {
                let p = min(1.0, max(0.0, Double(-dragOffset / screenWidth)))
                return (sortedSpaces[nextIndex], p)
            } else {
                return (nil, 0.0)
            }
        } else {
            // Swiping Right -> Towards leftward space
            let prevIndex = currentSpaceIndex - 1
            if prevIndex >= 0 {
                let p = min(1.0, max(0.0, Double(dragOffset / screenWidth)))
                return (sortedSpaces[prevIndex], p)
            } else {
                return (nil, 0.0)
            }
        }
    }
    
    // MARK: - Overscroll Past Rightmost Space (Create Space Trigger)
    private let createSpaceDragThreshold: CGFloat = 110.0
    
    private var isOverscrollingPastRightmost: Bool {
        currentSpaceIndex >= sortedSpaces.count - 1 && dragOffset < 0
    }
    
    private var createSpaceProgress: Double {
        guard isOverscrollingPastRightmost else { return 0.0 }
        return min(1.0, max(0.0, Double(-dragOffset / createSpaceDragThreshold)))
    }
    
    // MARK: - Overscroll Past Leftmost Space (Downloads Trigger)
    private let downloadsDragThreshold: CGFloat = 110.0
    
    private var isOverscrollingPastLeftmost: Bool {
        currentSpaceIndex == 0 && dragOffset > 0
    }
    
    private var downloadsProgress: Double {
        guard isOverscrollingPastLeftmost else { return 0.0 }
        return min(1.0, max(0.0, Double(dragOffset / downloadsDragThreshold)))
    }
    
    // MARK: - Adaptive Color Logic
    private func isDark(for space: Space) -> Bool {
        space.isDarkGradient
    }
    
    private func textColor(for space: Space) -> Color {
        isDark(for: space) ? .white : Color(hex: "#16161A")
    }
    
    private func textMutedColor(for space: Space) -> Color {
        isDark(for: space) ? Color.white.opacity(0.7) : Color(hex: "#4E4E58")
    }
    
    private func separatorColor(for space: Space) -> Color {
        isDark(for: space) ? Color.white.opacity(0.2) : Color(hex: "#16161A").opacity(0.14)
    }
    
    public var body: some View {
        GeometryReader { fullGeo in
            let screenWidth = fullGeo.size.width
            
            ZStack {
                // MARK: - 1. Dynamic Space Gradient Background (Cross-fading with finger swipe)
                backgroundGradientLayer
                
                // MARK: - 2. Main Content & Dual-Slider for Progressive Space Swipe
                VStack(spacing: 0) {
                    // Top Header
                    topHeaderView
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                    
                    // Continuous Sliding Tabs Track
                    HStack(spacing: 0) {
                        ForEach(sortedSpaces) { space in
                            spaceTabsScrollView(for: space)
                                .frame(width: screenWidth)
                                .scrollDisabled(isDraggingTransition)
                        }
                    }
                    .frame(width: screenWidth * CGFloat(sortedSpaces.count), alignment: .leading)
                    .offset(x: -CGFloat(currentSpaceIndex) * screenWidth + dragOffset)
                    .frame(width: screenWidth, alignment: .leading)
                    .clipped()
                }
                
                // MARK: - 3. Circular Create Space Overscroll Badge (Pinned Trailing, Centered Vertically)
                if isOverscrollingPastRightmost && createSpaceProgress > 0.02 {
                    HStack {
                        Spacer()
                        createSpaceOverscrollBadge
                            .padding(.trailing, 22)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(50)
                }
                
                // Circular Downloads Overscroll Badge (Pinned Leading, Centered Vertically)
                if isOverscrollingPastLeftmost && downloadsProgress > 0.02 {
                    HStack {
                        downloadsOverscrollBadge
                            .padding(.leading, 22)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .zIndex(50)
                }
                
                // MARK: - 4. Bottom Centered Dock & Symmetrical Action Buttons
                VStack {
                    Spacer()
                    ZStack(alignment: .center) {
                        // Centered Space Dock
                        bottomDockBar
                        
                        // Symmetrical Action Buttons (Pencil on Left, Folder on Right)
                        HStack {
                            // Pencil Button to edit current space (Symmetric to folder button)
                            Button {
                                Haptics.light()
                                spaceToEdit = currentSpace
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(textColor(for: currentSpace))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        isDark(for: currentSpace)
                                            ? Color.white.opacity(0.2)
                                            : Color.black.opacity(0.12)
                                    )
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(InteractiveSpringButtonStyle())
                            .accessibilityLabel(String(localized: "edit_space", bundle: .main))
                            .padding(.leading, 20)
                            
                            Spacer()
                            
                            // Floating Create Folder Button
                            Button {
                                Haptics.light()
                                showingCreateFolderSheet = true
                            } label: {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(textColor(for: currentSpace))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        isDark(for: currentSpace)
                                            ? Color.white.opacity(0.2)
                                            : Color.black.opacity(0.12)
                                    )
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(InteractiveSpringButtonStyle())
                            .accessibilityLabel(String(localized: "create_folder", bundle: .main))
                            .padding(.trailing, 20)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            // Screen-wide horizontal swipe gesture for progressive space transition
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        
                        switch swipeDirection {
                        case .undetermined:
                            if abs(dx) > 6 && abs(dx) > abs(dy) * 1.15 {
                                swipeDirection = .horizontal
                                isDraggingTransition = true
                                applyDrag(dx: dx)
                            } else if abs(dy) > 6 && abs(dy) > abs(dx) * 1.15 {
                                swipeDirection = .vertical
                            }
                        case .horizontal:
                            applyDrag(dx: dx)
                        case .vertical:
                            break
                        }
                    }
                    .onEnded { value in
                        if swipeDirection == .horizontal || isDraggingTransition {
                            handleSwipeEnded(value: value, screenWidth: screenWidth)
                        } else {
                            dragOffset = 0
                        }
                        swipeDirection = .undetermined
                        isDraggingTransition = false
                    }
            )
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            NavigationStack {
                FolderCreatorView(
                    spaceId: currentSpace.id,
                    accentColor: currentSpace.primaryColor,
                    onCreated: { createdFolder in
                        showingCreateFolderSheet = false
                        expandedFolders.insert(createdFolder.name)
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingArchiveSheet) {
            ArchivedTabsView()
        }
        .sheet(item: $editingFolder) { folder in
            NavigationStack {
                FolderCreatorView(
                    spaceId: folder.spaceId,
                    accentColor: currentSpace.primaryColor,
                    folderToEdit: folder,
                    onUpdated: { updated in
                        if expandedFolders.contains(folder.name) {
                            expandedFolders.remove(folder.name)
                            expandedFolders.insert(updated.name)
                        }
                        editingFolder = nil
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $spaceToEdit) { space in
            SpaceEditorSheet(space: space)
        }
        .sheet(isPresented: $showingCreateSpaceSheet) {
            SpaceEditorSheet(space: nil)
        }
        .sheet(isPresented: $showingDownloadsSheet) {
            NavigationStack {
                DownloadsView(isPresentedModally: true)
            }
        }
        .onChange(of: tabManager.openTabs.count) { _, newCount in
            if newCount == 0 {
                dismiss()
            }
        }
        .onAppear {
            for folder in tabManager.folders(for: currentSpace.id) {
                expandedFolders.insert(folder.name)
            }
        }
    }
    
    // MARK: - Background Gradient Layer (Progressive real-time blending)
    private var backgroundGradientLayer: some View {
        ZStack {
            // Base Current Space Gradient (100% faithful to intended space colors, independent of device theme)
            currentSpace.gradientBackground
                .ignoresSafeArea()
            
            // Target Space Gradient with real-time opacity matching finger progress
            if let target = swipeProgressData.target, target.id != currentSpace.id {
                target.gradientBackground
                    .opacity(swipeProgressData.progress)
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Space Tabs ScrollView (Bank of links: Favorites, Pinned, Space Links)
    private func spaceTabsScrollView(for space: Space) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Zone Favorites (Compact tiles)
                favoritesCategoryView(for: space)
                
                // Simple fine horizontal line separator
                horizontalSeparator(for: space)
                
                // 2. Zone Pinned (Flat rows with folders, directly on gradient)
                pinnedCategoryView(for: space)
                
                // Simple fine horizontal line separator
                horizontalSeparator(for: space)
                
                // 3. Zone Space Links (with "+" new tab as top item)
                spaceLinksCategoryView(for: space)
                
                // Archived tabs shortcut banner if any
                if !tabManager.archivedTabs.isEmpty {
                    archivedTabsBannerView(for: space)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 96)
        }
    }
    
    // MARK: - Horizontal Separator
    private func horizontalSeparator(for space: Space) -> some View {
        Rectangle()
            .fill(separatorColor(for: space))
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
    }
    
    // MARK: - Top Header (Continuous Fade Between Spaces)
    private var topHeaderView: some View {
        let currentText = textColor(for: currentSpace)
        let currentDark = isDark(for: currentSpace)
        let progress = swipeProgressData.progress
        let target = swipeProgressData.target
        
        // Ancien espace (icône + nom) : disparaît progressivement jusqu'à totale disparition à 50% du scroll
        let oldHeaderOpacity: Double = (target != nil && target?.id != currentSpace.id)
            ? max(0.0, 1.0 - (progress * 2.0))
            : 1.0
        
        // Prochain espace (icône + nom) : apparaît en fondu de 50% à 100% du scroll
        let newHeaderOpacity: Double = (target != nil && target?.id != currentSpace.id)
            ? min(1.0, max(0.0, (progress - 0.5) * 2.0))
            : 0.0
        
        return HStack(alignment: .center) {
            ZStack(alignment: .leading) {
                // Ancien espace (icône + nom)
                spaceTitleAndIcon(for: currentSpace)
                    .opacity(oldHeaderOpacity)
                
                // Prochain espace (icône + nom)
                if let nextSpace = target, nextSpace.id != currentSpace.id {
                    spaceTitleAndIcon(for: nextSpace)
                        .opacity(newHeaderOpacity)
                }
            }
            
            Spacer()
            
            // Dismiss / Close button
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(currentText.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(currentDark ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }
    
    private func spaceTitleAndIcon(for space: Space) -> some View {
        let spaceText = textColor(for: space)
        return HStack(spacing: 10) {
            SpaceIconView(
                icon: space.iconName,
                color: spaceText,
                size: 24
            )
            
            Text(space.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(spaceText)
                .lineLimit(1)
        }
    }
    
    // MARK: - 1. Favorites (Compact tiles with favicon)
    private func favoritesCategoryView(for space: Space) -> some View {
        let favorites = tabManager.favoriteTabs(for: space)
        let muted = textMutedColor(for: space)
        let dark = isDark(for: space)
        
        return VStack(alignment: .leading, spacing: 8) {
            if favorites.isEmpty {
                HStack {
                    Text("no_favorites")
                        .font(.system(size: 12))
                        .foregroundColor(muted.opacity(0.7))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(favorites) { tab in
                        favoriteTileView(tab: tab, inSpace: space)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isTargetedFavorites ? (dark ? Color.white : Color.black) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(isTargetedFavorites ? (dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)) : Color.clear)
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let tabId = extractTabId(from: first) else { return false }
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabManager.moveTabToZone(tabId: tabId, to: .favorite, inSpace: space)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargetedFavorites = targeted
            }
        }
    }
    
    private func favoriteTileView(tab: Tab, inSpace space: Space) -> some View {
        let isActive = tabManager.activeTab?.url == tab.url || tab.id == tabManager.activeTabId
        let dark = isDark(for: space)
        let nonActiveText = textColor(for: space)
        
        return Button {
            Haptics.selection()
            onSelectTab?()
            tabManager.openLinkFromSpace(tab: tab)
            dismiss()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.92) : (dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isActive ? Color.white : (dark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)), lineWidth: 1)
                    )
                
                TabFaviconView(tab: tab, size: 26, fallbackColor: isActive ? Color(hex: "#18181C") : nonActiveText)
            }
            .frame(width: 54, height: 54)
            .shadow(color: isActive ? Color.black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onDrag {
            Haptics.selection()
            return NSItemProvider(object: "tab:\(tab.id.uuidString)" as NSString)
        }
        .contextMenu {
            tabContextMenu(tab: tab, currentZone: .favorite, space: space)
        }
    }
    
    // MARK: - 2. Pinned (Flat rows directly on gradient, no section title)
    private func pinnedCategoryView(for space: Space) -> some View {
        let folderGroups = tabManager.pinnedTabsByFolder(for: space.id)
        let totalPinnedCount = folderGroups.reduce(0) { $0 + $1.tabs.count }
        let spaceText = textColor(for: space)
        let spaceMuted = textMutedColor(for: space)
        let dark = isDark(for: space)
        
        return VStack(alignment: .leading, spacing: 6) {
            if totalPinnedCount == 0 && tabManager.folders(for: space.id).isEmpty {
                HStack {
                    Text("no_pinned_tabs")
                        .font(.system(size: 12))
                        .foregroundColor(spaceMuted.opacity(0.7))
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(folderGroups.indices, id: \.self) { idx in
                        let group = folderGroups[idx]
                        if let folder = group.folder {
                            let folderName = folder.name
                            let isExpanded = expandedFolders.contains(folderName)
                            
                            VStack(spacing: 4) {
                                Button {
                                    Haptics.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if isExpanded {
                                            expandedFolders.remove(folderName)
                                        } else {
                                            expandedFolders.insert(folderName)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(spaceText.opacity(0.6))
                                            .frame(width: 12)
                                        
                                        SpaceIconView(
                                            icon: folder.iconName ?? "folder",
                                            color: .yellow.opacity(0.95),
                                            size: 15
                                        )
                                        
                                        Text(folderName)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(spaceText)
                                        
                                        Spacer()
                                        
                                        Text("\(group.tabs.count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(spaceText.opacity(0.7))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingFolder = folder
                                    } label: {
                                        Label(String(localized: "edit_folder", bundle: .main), systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            tabManager.deleteFolder(id: folder.id)
                                        }
                                    } label: {
                                        Label(String(localized: "delete_folder", bundle: .main), systemImage: "trash")
                                    }
                                }
                                
                                if isExpanded {
                                    VStack(spacing: 4) {
                                        ForEach(group.tabs) { tab in
                                            pinnedTabFlatRow(tab: tab, inSpace: space)
                                        }
                                    }
                                    .padding(.leading, 18)
                                }
                            }
                        } else {
                            ForEach(group.tabs) { tab in
                                pinnedTabFlatRow(tab: tab, inSpace: space)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isTargetedPinned ? (dark ? Color.white : Color.black) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(isTargetedPinned ? (dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)) : Color.clear)
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let tabId = extractTabId(from: first) else { return false }
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabManager.moveTabToZone(tabId: tabId, to: .pinned, inSpace: space)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargetedPinned = targeted
            }
        }
    }
    
    private func pinnedTabFlatRow(tab: Tab, inSpace space: Space) -> some View {
        let isActive = tabManager.activeTab?.url == tab.url || tab.id == tabManager.activeTabId
        let nonActiveText = textColor(for: space)
        
        return Button {
            Haptics.selection()
            onSelectTab?()
            tabManager.openLinkFromSpace(tab: tab)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                TabFaviconView(tab: tab, size: 20, fallbackColor: isActive ? Color(hex: "#18181C") : nonActiveText)
                
                Text(tab.title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isActive ? Color(hex: "#18181C") : nonActiveText)
                    .lineLimit(1)
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#18181C"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            Haptics.selection()
            return NSItemProvider(object: "tab:\(tab.id.uuidString)" as NSString)
        }
        .contextMenu {
            tabContextMenu(tab: tab, currentZone: .pinned, space: space)
        }
    }
    
    // MARK: - 3. Liens d'Espace (Banque de liens rattachés à l'espace)
    private func spaceLinksCategoryView(for space: Space) -> some View {
        let spaceLinks = tabManager.normalTabs(for: space.id)
        let dark = isDark(for: space)
        
        return VStack(alignment: .leading, spacing: 4) {
            // TOP ITEM: "+" new tab row, transparent, directly on gradient
            newTabOpenTabRow(for: space)
            
            // Space links list
            ForEach(spaceLinks) { tab in
                spaceLinkRowView(tab: tab, inSpace: space)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isTargetedNormal ? (dark ? Color.white : Color.black) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .background(isTargetedNormal ? (dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)) : Color.clear)
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let tabId = extractTabId(from: first) else { return false }
            Haptics.success()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabManager.moveTabToZone(tabId: tabId, to: .normal, inSpace: space)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargetedNormal = targeted
            }
        }
    }
    
    private func newTabOpenTabRow(for space: Space) -> some View {
        let muted = textMutedColor(for: space)
        
        return Button {
            Haptics.medium()
            onSelectTab?()
            dismiss()
            if let onOpenSearch = onOpenSearch {
                onOpenSearch()
            } else {
                _ = tabManager.openNewTab(spaceId: space.id, isPrivate: false)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(muted)
                    .frame(width: 20)
                
                Text("new_tab")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(muted)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    private func spaceLinkRowView(tab: Tab, inSpace space: Space) -> some View {
        let isActive = tabManager.activeTab?.url == tab.url || tab.id == tabManager.activeTabId
        let nonActiveText = textColor(for: space)
        
        return Button {
            Haptics.selection()
            onSelectTab?()
            tabManager.openLinkFromSpace(tab: tab)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                TabFaviconView(tab: tab, size: 20, fallbackColor: isActive ? Color(hex: "#18181C") : nonActiveText)
                
                Text(tab.title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isActive ? Color(hex: "#18181C") : nonActiveText)
                    .lineLimit(1)
                
                Spacer()
                
                // Delete button (X) to remove link from space
                Button {
                    Haptics.light()
                    withAnimation {
                        tabManager.closeTab(id: tab.id)
                    }
                    if tabManager.openTabs.isEmpty {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isActive ? Color(hex: "#18181C").opacity(0.6) : nonActiveText.opacity(0.55))
                        .frame(width: 22, height: 22)
                        .background(isActive ? Color.black.opacity(0.06) : (isDark(for: space) ? Color.white.opacity(0.14) : Color.black.opacity(0.08)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            Haptics.selection()
            return NSItemProvider(object: "tab:\(tab.id.uuidString)" as NSString)
        }
        .contextMenu {
            tabContextMenu(tab: tab, currentZone: .normal, space: space)
        }
    }
    
    // Context menu for links
    private func tabContextMenu(tab: Tab, currentZone: TabManager.TabZone, space: Space) -> some View {
        Group {
            Button {
                tabManager.openLinkFromSpace(tab: tab)
                dismiss()
            } label: {
                Label(String(localized: "open_link", bundle: .main), systemImage: "arrow.up.right")
            }
            
            if currentZone != .favorite {
                Button {
                    withAnimation {
                        tabManager.moveTabToZone(tabId: tab.id, to: .favorite, inSpace: space)
                    }
                } label: {
                    Label(String(localized: "add_to_favorites", bundle: .main), systemImage: "star.fill")
                }
            }
            
            if currentZone != .pinned {
                Button {
                    withAnimation {
                        tabManager.moveTabToZone(tabId: tab.id, to: .pinned, inSpace: space)
                    }
                } label: {
                    Label(String(localized: "pin_in_space", bundle: .main), systemImage: "pin.fill")
                }
            }
            
            if currentZone != .normal {
                Button {
                    withAnimation {
                        tabManager.moveTabToZone(tabId: tab.id, to: .normal, inSpace: space)
                    }
                } label: {
                    Label(String(localized: "convert_to_space_link", bundle: .main), systemImage: "link")
                }
            }
            
            // Move to another space
            Menu {
                ForEach(tabManager.spaces.filter { $0.id != space.id }) { targetSpace in
                    Button {
                        withAnimation {
                            tabManager.moveTabToSpace(tabId: tab.id, toSpaceId: targetSpace.id)
                        }
                    } label: {
                        Label(targetSpace.name, systemImage: targetSpace.iconName)
                    }
                }
            } label: {
                Label(String(localized: "move_to_space", bundle: .main), systemImage: "arrow.right.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                withAnimation {
                    tabManager.closeTab(id: tab.id)
                }
                if tabManager.openTabs.isEmpty {
                    dismiss()
                }
            } label: {
                Label(String(localized: "delete", bundle: .main), systemImage: "trash")
            }
        }
    }
    
    // MARK: - Archived Tabs Banner
    private func archivedTabsBannerView(for space: Space) -> some View {
        let spaceText = textColor(for: space)
        let spaceMuted = textMutedColor(for: space)
        let dark = isDark(for: space)
        
        return Button {
            Haptics.light()
            showingArchiveSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "archivebox.fill")
                    .foregroundColor(spaceText.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("archived_tabs")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(spaceText)
                    
                    Text(String(format: String(localized: "auto_archived_count", bundle: .main), tabManager.archivedTabs.count))
                        .font(.caption)
                        .foregroundColor(spaceMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(spaceText.opacity(0.6))
            }
            .padding(12)
            .background(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Centered Dock (Neutral Space Icons with Drag-to-Reorder & Edit)
    private var bottomDockBar: some View {
        HStack(spacing: 12) {
            ForEach(Array(sortedSpaces.enumerated()), id: \.element.id) { index, space in
                let isSelected = space.id == tabManager.activeSpaceId
                let isBeingDragged = draggedSpaceId == space.id
                let isHovered = hoveredDockSpaceId == space.id && draggedSpaceId == nil
                let fromIdx = sortedSpaces.firstIndex(where: { $0.id == draggedSpaceId })
                let isSlotTargeted = prospectiveTargetIndex == index && draggedSpaceId != nil && fromIdx != index
                
                ZStack {
                    // Dashed ghost placeholder highlighting the open slot ("trou attribué") when an icon has shifted away
                    if isSlotTargeted {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                Color.white.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                            .frame(width: 44, height: 44)
                            .transition(.opacity)
                    }
                    
                    spaceDockItemView(
                        space: space,
                        index: index,
                        isSelected: isSelected,
                        isBeingDragged: isBeingDragged,
                        isHovered: isHovered
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        )
    }
    
    @ViewBuilder
    private func spaceDockItemView(
        space: Space,
        index: Int,
        isSelected: Bool,
        isBeingDragged: Bool,
        isHovered: Bool
    ) -> some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.28))
                    .matchedGeometryEffect(id: "activeSpaceIndicator", in: namespace)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    )
            } else if isHovered {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 44, height: 44)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 44, height: 44)
            }
            
            SpaceIconView(
                icon: space.iconName,
                color: isSelected ? .white : .white.opacity(0.55),
                size: 19
            )
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isBeingDragged ? 1.18 : (isHovered ? 1.2 : 1.0))
        .shadow(
            color: isBeingDragged ? Color.black.opacity(0.45) : Color.clear,
            radius: isBeingDragged ? 12 : 0,
            x: 0,
            y: isBeingDragged ? 6 : 0
        )
        .offset(isBeingDragged ? draggedSpaceOffset : CGSize(width: computedOffset(for: index), height: 0))
        .zIndex(isBeingDragged ? 100 : Double(20 - index))
        .animation(
            isBeingDragged ? nil : .spring(response: 0.28, dampingFraction: 0.75),
            value: prospectiveTargetIndex
        )
        // High priority touch & drag handling (Tap to Switch, Drag to Reorder)
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if draggedSpaceId == nil {
                        draggedSpaceId = space.id
                        prospectiveTargetIndex = index
                        Haptics.selection()
                    }
                    draggedSpaceOffset = value.translation
                    
                    let slotDistance: CGFloat = 56.0
                    let slotShift = Int(round(value.translation.width / slotDistance))
                    let newTarget = max(0, min(sortedSpaces.count - 1, index + slotShift))
                    
                    if newTarget != prospectiveTargetIndex {
                        prospectiveTargetIndex = newTarget
                        Haptics.selection()
                    }
                }
                .onEnded { value in
                    let targetIdx = prospectiveTargetIndex ?? index
                    
                    if targetIdx != index {
                        Haptics.success()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            tabManager.moveSpace(spaceId: space.id, toIndex: targetIdx)
                            draggedSpaceId = nil
                            draggedSpaceOffset = .zero
                            prospectiveTargetIndex = nil
                        }
                    } else {
                        Haptics.light()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            draggedSpaceId = nil
                            draggedSpaceOffset = .zero
                            prospectiveTargetIndex = nil
                        }
                    }
                }
        )
        .onTapGesture {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                tabManager.switchSpace(to: space.id)
            }
        }
        // Accepts tabs dragged from the space tab list
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            if let tabId = extractTabId(from: first) {
                Haptics.success()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    tabManager.moveTabToSpace(tabId: tabId, toSpaceId: space.id)
                }
                return true
            }
            return false
        } isTargeted: { targeted in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if targeted {
                    hoveredDockSpaceId = space.id
                } else if hoveredDockSpaceId == space.id {
                    hoveredDockSpaceId = nil
                }
            }
        }
    }
    
    private func computedOffset(for index: Int) -> CGFloat {
        guard let draggedId = draggedSpaceId,
              let fromIdx = sortedSpaces.firstIndex(where: { $0.id == draggedId }),
              let targetIdx = prospectiveTargetIndex else {
            return 0
        }
        
        let slotDistance: CGFloat = 56.0
        
        if targetIdx > fromIdx {
            if index > fromIdx && index <= targetIdx {
                return -slotDistance
            }
        } else if targetIdx < fromIdx {
            if index >= targetIdx && index < fromIdx {
                return slotDistance
            }
        }
        return 0
    }

    @Namespace private var namespace
    
    // MARK: - Helper Methods
    private func extractTabId(from string: String) -> UUID? {
        if string.hasPrefix("tab:") {
            return UUID(uuidString: String(string.dropFirst(4)))
        }
        return UUID(uuidString: string)
    }
    
    private func extractSpaceId(from string: String) -> UUID? {
        if string.hasPrefix("space:") {
            return UUID(uuidString: String(string.dropFirst(6)))
        }
        return UUID(uuidString: string)
    }
    
    // MARK: - Drag Resistance Calculation
    private func applyDrag(dx: CGFloat) {
        if dx < 0 && currentSpaceIndex >= sortedSpaces.count - 1 {
            // Rightmost space: rubber band resistance when pulling left to create space
            let damped = -pow(abs(dx), 0.82) * 1.6
            dragOffset = damped
            
            if -damped >= createSpaceDragThreshold && !hasTriggeredCreateSpaceHaptic {
                hasTriggeredCreateSpaceHaptic = true
                Haptics.medium()
            } else if -damped < createSpaceDragThreshold && hasTriggeredCreateSpaceHaptic {
                hasTriggeredCreateSpaceHaptic = false
            }
        } else if dx > 0 && currentSpaceIndex == 0 {
            // Leftmost space: rubber band resistance when pulling right to view downloads
            let damped = pow(dx, 0.82) * 1.6
            dragOffset = damped
            
            if damped >= downloadsDragThreshold && !hasTriggeredDownloadsHaptic {
                hasTriggeredDownloadsHaptic = true
                Haptics.medium()
            } else if damped < downloadsDragThreshold && hasTriggeredDownloadsHaptic {
                hasTriggeredDownloadsHaptic = false
            }
        } else {
            dragOffset = dx
        }
    }
    
    // MARK: - Swipe Gesture Completion
    private func handleSwipeEnded(value: DragGesture.Value, screenWidth: CGFloat) {
        let velocity = value.predictedEndTranslation.width - value.translation.width
        let threshold: CGFloat = screenWidth * 0.22
        let count = sortedSpaces.count
        
        // Handle overscroll past rightmost space to trigger space creation
        if isOverscrollingPastRightmost {
            let reached100 = createSpaceProgress >= 1.0
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                dragOffset = 0
                isDraggingTransition = false
                hasTriggeredCreateSpaceHaptic = false
            }
            if reached100 {
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    showingCreateSpaceSheet = true
                }
            }
            return
        }
        
        // Handle overscroll past leftmost space to trigger downloads
        if isOverscrollingPastLeftmost {
            let reached100 = downloadsProgress >= 1.0
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                dragOffset = 0
                isDraggingTransition = false
                hasTriggeredDownloadsHaptic = false
            }
            if reached100 {
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    showingDownloadsSheet = true
                }
            }
            return
        }
        
        guard count > 1 else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                dragOffset = 0
                isDraggingTransition = false
            }
            return
        }
        
        if (value.translation.width < -threshold || velocity < -350), currentSpaceIndex < count - 1 {
            // Transition to NEXT space
            let targetSpace = sortedSpaces[currentSpaceIndex + 1]
            Haptics.selection()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                dragOffset = -screenWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                tabManager.switchSpace(to: targetSpace.id)
                dragOffset = 0
                isDraggingTransition = false
            }
        } else if (value.translation.width > threshold || velocity > 350), currentSpaceIndex > 0 {
            // Transition to PREVIOUS space
            let targetSpace = sortedSpaces[currentSpaceIndex - 1]
            Haptics.selection()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                dragOffset = screenWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                tabManager.switchSpace(to: targetSpace.id)
                dragOffset = 0
                isDraggingTransition = false
            }
        } else {
            // Snap back
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                dragOffset = 0
                isDraggingTransition = false
            }
        }
    }
    
    // MARK: - Create Space Overscroll Circular Badge
    private var createSpaceOverscrollBadge: some View {
        let isComplete = createSpaceProgress >= 1.0
        let ringColor: Color = isComplete ? .green : (isDark(for: currentSpace) ? .white : Color(hex: "#16161A"))
        
        return ZStack {
            // Frosted blur circular pill background
            Circle()
                .fill(
                    isDark(for: currentSpace)
                        ? Color.white.opacity(0.18)
                        : Color.black.opacity(0.12)
                )
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 56, height: 56)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            // Outer circular track (unfilled ring)
            Circle()
                .stroke(
                    isDark(for: currentSpace) ? Color.white.opacity(0.22) : Color.black.opacity(0.15),
                    lineWidth: 3.5
                )
                .frame(width: 56, height: 56)
            
            // Progress circular fill ring
            Circle()
                .trim(from: 0, to: createSpaceProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 56, height: 56)
                .animation(.interactiveSpring(), value: createSpaceProgress)
            
            // Center Plus Icon (keeps icon, color changes to accent green upon reaching 100%)
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ringColor)
                .scaleEffect(isComplete ? 1.15 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isComplete)
        }
        .scaleEffect(0.82 + 0.18 * createSpaceProgress)
        .offset(x: max(0, 24 * (1.0 - createSpaceProgress)))
    }
    
    // MARK: - Downloads Overscroll Circular Badge (Leading Edge)
    private var downloadsOverscrollBadge: some View {
        let isComplete = downloadsProgress >= 1.0
        let ringColor: Color = isComplete ? .cyan : (isDark(for: currentSpace) ? .white : Color(hex: "#16161A"))
        
        return ZStack {
            // Frosted blur circular pill background
            Circle()
                .fill(
                    isDark(for: currentSpace)
                        ? Color.white.opacity(0.18)
                        : Color.black.opacity(0.12)
                )
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 56, height: 56)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            // Outer circular track (unfilled ring)
            Circle()
                .stroke(
                    isDark(for: currentSpace) ? Color.white.opacity(0.22) : Color.black.opacity(0.15),
                    lineWidth: 3.5
                )
                .frame(width: 56, height: 56)
            
            // Progress circular fill ring
            Circle()
                .trim(from: 0, to: downloadsProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 56, height: 56)
                .animation(.interactiveSpring(), value: downloadsProgress)
            
            // Center Download Icon (keeps icon, color changes to accent cyan upon reaching 100%)
            Image(systemName: "arrow.down")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ringColor)
                .scaleEffect(isComplete ? 1.15 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isComplete)
        }
        .scaleEffect(0.82 + 0.18 * downloadsProgress)
        .offset(x: min(0, -24 * (1.0 - downloadsProgress)))
    }
}

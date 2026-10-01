import SwiftUI

/// Pin View matching the updated Share Extension design:
/// - No Options menu, no top cross.
/// - Destination space horizontal selector.
/// - Type selector: Favorite / Pinned.
/// - Folder section: only when "Pinned" is chosen.
///   - If folders exist: folder buttons (toggleable, max 1 selected) + "Create Folder" button.
///   - If no folders exist: no folder buttons, only "Create Folder" button.
/// - Folder creation: name + optional emoji / Zen space icon.
public enum PinDestinationType: String, CaseIterable, Identifiable {
    case favorite = "Favorite"
    case pinned = "Pinned"
    
    public var id: String { rawValue }
}

public struct PinTabView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    public let url: URL
    public let initialTitle: String
    
    @State private var title: String
    @State private var selectedSpaceId: UUID
    @State private var destinationType: PinDestinationType = .pinned
    @State private var selectedFolder: String? = nil
    
    // Folder creation sheet state
    @State private var showingCreateFolderSheet: Bool = false
    @State private var newFolderName: String = ""
    @State private var newFolderIcon: String = "folder"
    
    @State private var isSavedSuccessfully: Bool = false
    
    public init(url: URL, initialTitle: String) {
        self.url = url
        self.initialTitle = initialTitle
        _title = State(initialValue: initialTitle.isEmpty ? (url.host ?? "Link") : initialTitle)
        _selectedSpaceId = State(initialValue: TabManager.shared.activeSpaceId)
    }
    
    private var selectedSpace: Space? {
        tabManager.spaces.first(where: { $0.id == selectedSpaceId }) ?? tabManager.spaces.first
    }
    
    private var activeColor: Color {
        selectedSpace?.primaryColor ?? themeManager.accentColor
    }
    
    private var existingFolders: [ZenFolder] {
        tabManager.folders(for: selectedSpaceId)
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Clean Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedSpace?.gradientBackground ?? LinearGradient(colors: [activeColor, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "pin.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("pin_link")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("add_to_favorites_or_pinned")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                    
                    // Link preview card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(activeColor)
                                .frame(width: 26, height: 26)
                                .background(activeColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            TextField(String(localized: "link_title_placeholder", bundle: .main), text: $title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text(url.absoluteString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // 1. Destination Space Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("section_destination_space")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(tabManager.spaces) { space in
                                    let isSelected = space.id == selectedSpaceId
                                    let spaceColor = space.primaryColor
                                    
                                    Button {
                                        Haptics.selection()
                                        selectedSpaceId = space.id
                                        selectedFolder = nil
                                    } label: {
                                        HStack(spacing: 7) {
                                            SpaceIconView(icon: space.iconName, color: isSelected ? .white : spaceColor, size: 14)
                                            
                                            Text(space.name)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : .primary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ? AnyShapeStyle(space.gradientBackground) : AnyShapeStyle(spaceColor.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(isSelected ? spaceColor : spaceColor.opacity(0.3), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // 2. Tab Type Selector (Favori vs Épinglé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("section_tab_type")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 10) {
                            // Favori button
                            let isFavSelected = destinationType == .favorite
                            Button {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    destinationType = .favorite
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13))
                                    Text("tab_type_favorite")
                                        .font(.system(size: 13, weight: isFavSelected ? .bold : .medium))
                                }
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(isFavSelected ? Color.yellow.opacity(0.2) : Color.primary.opacity(0.04))
                                .foregroundColor(isFavSelected ? .orange : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isFavSelected ? Color.orange : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Épinglé button
                            let isPinSelected = destinationType == .pinned
                            Button {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    destinationType = .pinned
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 13))
                                    Text("pinned")
                                        .font(.system(size: 13, weight: isPinSelected ? .bold : .medium))
                                }
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(isPinSelected ? activeColor.opacity(0.18) : Color.primary.opacity(0.04))
                                .foregroundColor(isPinSelected ? activeColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isPinSelected ? activeColor : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // 3. Folder Section: strictly when "Épinglé" is chosen
                    if destinationType == .pinned {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("section_folder")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // If folders exist in this space, display toggleable folder buttons
                                    ForEach(existingFolders) { folder in
                                        let isSelected = selectedFolder == folder.name
                                        Button {
                                            Haptics.selection()
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                // Clickable and unclickable (toggle selection)
                                                if isSelected {
                                                    selectedFolder = nil
                                                } else {
                                                    selectedFolder = folder.name
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                SpaceIconView(icon: folder.iconName ?? "folder", color: isSelected ? activeColor : .primary, size: 13)
                                                
                                                Text(folder.name)
                                                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                isSelected ? activeColor.opacity(0.16) : Color.primary.opacity(0.05)
                                            )
                                            .foregroundColor(isSelected ? activeColor : .primary)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(isSelected ? activeColor.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // "Créer un dossier" button (always present)
                                    Button {
                                        Haptics.light()
                                        newFolderName = ""
                                        newFolderIcon = "folder"
                                        showingCreateFolderSheet = true
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("create_folder")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(activeColor.opacity(0.12))
                                        .foregroundColor(activeColor)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(activeColor.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Main Action Button
                    Button(action: handleSaveAction) {
                        HStack(spacing: 8) {
                            if isSavedSuccessfully {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("pinned_success")
                                    .font(.system(size: 15, weight: .bold))
                            } else {
                                Image(systemName: destinationType == .favorite ? "star.fill" : "pin.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text(mainButtonTitle)
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            isSavedSuccessfully ? Color.green : activeColor
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: activeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSavedSuccessfully)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
            .padding(.bottom, 12)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showingCreateFolderSheet) {
            NavigationStack {
                FolderCreatorView(
                    spaceId: selectedSpaceId,
                    accentColor: activeColor,
                    onCreated: { createdFolder in
                        showingCreateFolderSheet = false
                        selectedFolder = createdFolder.name
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSpaceId)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: destinationType)
        .animation(.easeInOut(duration: 0.25), value: isSavedSuccessfully)
    }
    
    private var mainButtonTitle: String {
        if destinationType == .favorite {
            return String(localized: "add_to_favorites", bundle: .main)
        } else if let folder = selectedFolder {
            return "\(String(localized: "pin_tab", bundle: .main)) (\(folder))"
        } else {
            return "\(String(localized: "pin_tab", bundle: .main)) (\(selectedSpace?.name ?? ""))"
        }
    }
    
    private func handleSaveAction() {
        Haptics.success()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? (url.host ?? "Link") : cleanTitle
        let cleanURL = AdBlockService.shared.cleanTrackingParameters(from: url)
        
        if destinationType == .favorite {
            let favTab = Tab(
                url: cleanURL,
                title: finalTitle,
                spaceId: selectedSpaceId,
                isPinned: false,
                isFavorite: true,
                profileId: selectedSpace?.profileId
            )
            tabManager.tabs.append(favTab)
            tabManager.saveToDisk()
        } else {
            tabManager.addPinnedTab(
                url: cleanURL,
                title: finalTitle,
                spaceId: selectedSpaceId,
                folder: selectedFolder
            )
        }
        
        withAnimation {
            isSavedSuccessfully = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

/// Standalone sheet for creating or editing a folder with name and optional icon/emoji selection
public struct FolderCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    
    public let spaceId: UUID
    public let accentColor: Color
    public var folderToEdit: ZenFolder?
    public var onCreated: ((ZenFolder) -> Void)?
    public var onUpdated: ((ZenFolder) -> Void)?
    
    @State private var folderName: String
    @State private var selectedIcon: String
    
    public init(
        spaceId: UUID,
        accentColor: Color,
        folderToEdit: ZenFolder? = nil,
        onCreated: ((ZenFolder) -> Void)? = nil,
        onUpdated: ((ZenFolder) -> Void)? = nil
    ) {
        self.spaceId = spaceId
        self.accentColor = accentColor
        self.folderToEdit = folderToEdit
        self.onCreated = onCreated
        self.onUpdated = onUpdated
        
        _folderName = State(initialValue: folderToEdit?.name ?? "")
        _selectedIcon = State(initialValue: folderToEdit?.iconName ?? "folder")
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Folder name input
            HStack(spacing: 12) {
                SpaceIconView(icon: selectedIcon, color: accentColor, size: 28)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                TextField(String(localized: "folder_name_placeholder", bundle: .main), text: $folderName)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Icon / Emoji Selector (showNavigationTitle: false to preserve folder title)
            SpaceIconSelectionView(selectedIcon: $selectedIcon, accentColor: accentColor, showNavigationTitle: false)
        }
        .navigationTitle(folderToEdit != nil ? String(localized: "edit_folder", bundle: .main) : String(localized: "new_folder", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel", bundle: .main)) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(folderToEdit != nil ? String(localized: "save", bundle: .main) : String(localized: "create", bundle: .main)) {
                    Haptics.success()
                    let clean = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let iconToSave = selectedIcon.isEmpty || selectedIcon == "folder" ? nil : selectedIcon
                    
                    if let existing = folderToEdit {
                        if let updated = tabManager.updateFolder(
                            id: existing.id,
                            newName: clean.isEmpty ? existing.name : clean,
                            newIconName: iconToSave
                        ) {
                            onUpdated?(updated)
                        }
                    } else {
                        let created = tabManager.createFolder(
                            name: clean.isEmpty ? String(localized: "folder", bundle: .main) : clean,
                            iconName: iconToSave,
                            spaceId: spaceId
                        )
                        onCreated?(created)
                    }
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

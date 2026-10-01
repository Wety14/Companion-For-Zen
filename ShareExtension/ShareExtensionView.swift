import SwiftUI

public enum ShareDestination: String, CaseIterable, Identifiable {
    case favorite = "Favorite"
    case pinned = "Pinned"
    
    public var id: String { rawValue }
    
    public var localizedName: String {
        switch self {
        case .favorite: return String(localized: "tab_type_favorite", bundle: .main)
        case .pinned: return String(localized: "pinned", bundle: .main)
        }
    }
    
    public var icon: String {
        switch self {
        case .favorite: return "star.fill"
        case .pinned: return "pin.fill"
        }
    }
}

public struct ShareExtensionView: View {
    public let url: URL
    public let initialTitle: String
    public var onSave: () -> Void
    public var onCancel: () -> Void
    
    @State private var title: String
    @State private var spaces: [ShareSpace] = []
    @State private var selectedSpaceId: UUID = UUID()
    @State private var destinationType: ShareDestination = .pinned
    @State private var existingFolders: [ZenFolder] = []
    
    // Folder selection state (only for .pinned)
    @State private var selectedFolder: String? = nil
    @State private var showingCreateFolderSheet: Bool = false
    
    @State private var isSaving: Bool = false
    @State private var isSavedSuccessfully: Bool = false
    
    public init(
        url: URL,
        initialTitle: String,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.url = url
        self.initialTitle = initialTitle
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initialTitle.isEmpty ? (url.host ?? "Lien partagé") : initialTitle)
    }
    
    private var selectedSpace: ShareSpace? {
        spaces.first(where: { $0.id == selectedSpaceId })
    }
    
    private var activeColor: Color {
        if let hex = selectedSpace?.themeColorHex {
            return Color(hex: hex)
        }
        return Color(hex: "#537CF7")
    }
    
    public var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isSaving && !isSavedSuccessfully {
                        onCancel()
                    }
                }
            
            // Floating Sheet Card
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    // Grabber handle
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    
                    // Clean Header (without Options dropdown or top cross)
                    HStack {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#537CF7"), Color(hex: "#F27F59")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "globe")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Zen Browser")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(String(localized: "add_to_space", bundle: .main))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Link preview card
                    VStack(alignment: .leading, spacing: 8) {
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
                        
                        Text(verbatim: url.absoluteString)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    
                    // Space Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "section_destination_space", bundle: .main))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(spaces) { space in
                                    let isSelected = space.id == selectedSpaceId
                                    let spaceColor = Color(hex: space.themeColorHex)
                                    let gradient = LinearGradient(
                                        colors: space.gradientColorsHex.map { Color(hex: $0) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    
                                    Button(action: {
                                        selectSpace(space)
                                    }) {
                                        HStack(spacing: 7) {
                                            ShareSpaceIconView(icon: space.iconName, color: isSelected ? .white : spaceColor)
                                            
                                            Text(verbatim: space.name)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : .primary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(spaceColor.opacity(0.1))
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
                    
                    // Destination Tier Selector (Favori vs Épinglé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "section_tab_type", bundle: .main))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 8) {
                            ForEach(ShareDestination.allCases) { dest in
                                let isSelected = destinationType == dest
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        destinationType = dest
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: dest.icon)
                                            .font(.system(size: 12))
                                        Text(dest.localizedName)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isSelected ? activeColor.opacity(0.16) : Color.primary.opacity(0.04)
                                    )
                                    .foregroundColor(isSelected ? activeColor : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? activeColor : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Folder Selector (strictly only for Pinned tabs)
                    if destinationType == .pinned {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "section_folder", bundle: .main))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // If folders exist in this space, show toggleable chips
                                    ForEach(existingFolders) { folder in
                                        let isSelected = selectedFolder == folder.name
                                        Button(action: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                if isSelected {
                                                    selectedFolder = nil
                                                } else {
                                                    selectedFolder = folder.name
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 5) {
                                                ShareSpaceIconView(icon: folder.iconName ?? "folder", color: isSelected ? activeColor : .primary, size: 12)
                                                Text(verbatim: folder.name)
                                                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                isSelected ? activeColor.opacity(0.15) : Color.primary.opacity(0.04)
                                            )
                                            .foregroundColor(
                                                isSelected ? activeColor : .primary
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(
                                                        isSelected ? activeColor.opacity(0.5) : Color.primary.opacity(0.08),
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // "Créer un dossier" button (always present)
                                    Button(action: {
                                        showingCreateFolderSheet = true
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 11, weight: .bold))
                                            Text(String(localized: "create_folder", bundle: .main))
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
                    } else if destinationType == .favorite {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            let prof = selectedSpace?.profileId ?? "Personnel"
                            Text(verbatim: "\(String(localized: "zen_profile", bundle: .main)): \(prof)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Main Action Button
                    Button(action: handleSaveAction) {
                        HStack(spacing: 8) {
                            if isSavedSuccessfully {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(String(localized: "pinned_success", bundle: .main))
                                    .font(.system(size: 16, weight: .bold))
                            } else if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: destinationType.icon)
                                    .font(.system(size: 14, weight: .bold))
                                Text(mainButtonTitle)
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            isSavedSuccessfully
                                ? Color.green
                                : activeColor
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: activeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving || isSavedSuccessfully)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                }
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: 10)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showingCreateFolderSheet) {
            NavigationStack {
                ShareFolderCreatorView(
                    spaceId: selectedSpaceId,
                    accentColor: activeColor,
                    onCreated: { newFolder in
                        showingCreateFolderSheet = false
                        existingFolders = ShareDataManager.shared.loadZenFolders(for: selectedSpaceId)
                        selectedFolder = newFolder.name
                    }
                )
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            loadInitialData()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedSpaceId)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: destinationType)
        .animation(.easeInOut(duration: 0.25), value: isSavedSuccessfully)
    }
    
    private var mainButtonTitle: String {
        let spaceName = selectedSpace?.name ?? ""
        switch destinationType {
        case .favorite:
            return String(localized: "add_to_favorites", bundle: .main)
        case .pinned:
            if let folder = selectedFolder {
                return "\(String(localized: "pin_tab", bundle: .main)) (\(folder))"
            }
            return "\(String(localized: "pin_tab", bundle: .main)) (\(spaceName))"
        }
    }
    
    private func loadInitialData() {
        let loadedSpaces = ShareDataManager.shared.loadSpaces()
        self.spaces = loadedSpaces
        if let first = loadedSpaces.first {
            self.selectedSpaceId = first.id
            self.existingFolders = ShareDataManager.shared.loadZenFolders(for: first.id)
        }
    }
    
    private func selectSpace(_ space: ShareSpace) {
        selectedSpaceId = space.id
        existingFolders = ShareDataManager.shared.loadZenFolders(for: space.id)
        if let current = selectedFolder, !existingFolders.contains(where: { $0.name == current }) {
            selectedFolder = nil
        }
    }
    
    private func handleSaveAction() {
        isSaving = true
        
        let finalFolder: String? = (destinationType == .pinned) ? selectedFolder : nil
        
        ShareDataManager.shared.saveSharedTab(
            url: url,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            spaceId: selectedSpaceId,
            isPinned: destinationType == .pinned,
            isFavorite: destinationType == .favorite,
            profileId: selectedSpace?.profileId,
            folder: finalFolder
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            isSavedSuccessfully = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onSave()
            }
        }
    }
}

// MARK: - Share Extension Folder Creator View
public struct ShareFolderCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    public let spaceId: UUID
    public let accentColor: Color
    public var onCreated: (ZenFolder) -> Void
    
    @State private var folderName: String = ""
    @State private var selectedIcon: String = "folder"
    @State private var pickerMode: Int = 0 // 0 = Icônes, 1 = Emojis
    
    private let availableIcons: [String] = [
        "folder", "tray", "bookmark", "star", "tag", "briefcase", "book", "doc.text",
        "heart", "lightbulb", "gear", "archivebox", "globe", "cart", "gift", "flag",
        "sparkles", "music.note", "film", "camera", "gamecontroller", "creditcard",
        "house", "wrench.and.screwdriver"
    ]
    
    private let availableEmojis: [String] = [
        "📁", "📂", "📌", "⭐", "💼", "📚", "🏷️", "💡",
        "🎨", "🎬", "🎵", "🎮", "🛒", "✈️", "🔥", "❤️",
        "🚀", "🍕", "💻", "☕", "📱", "🎧", "⚡", "🌟"
    ]
    
    public var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ShareSpaceIconView(icon: selectedIcon, color: accentColor, size: 26)
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
            
            Picker(selection: $pickerMode, label: EmptyView()) {
                Text(String(localized: "icons", bundle: .main)).tag(0)
                Text(String(localized: "emojis", bundle: .main)).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            
            ScrollView {
                if pickerMode == 0 {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            let isSelected = selectedIcon == icon
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(isSelected ? .white : accentColor)
                                    .frame(width: 46, height: 46)
                                    .background(isSelected ? accentColor : Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(availableEmojis, id: \.self) { emoji in
                            let isSelected = selectedIcon == emoji
                            Button {
                                selectedIcon = emoji
                            } label: {
                                Text(verbatim: emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 46, height: 46)
                                    .background(isSelected ? accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxHeight: 220)
        }
        .navigationTitle(String(localized: "new_folder", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cancel", bundle: .main)) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "create", bundle: .main)) {
                    let clean = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let iconToSave = selectedIcon.isEmpty || selectedIcon == "folder" ? nil : selectedIcon
                    let created = ShareDataManager.shared.createFolder(
                        name: clean.isEmpty ? String(localized: "folder", bundle: .main) : clean,
                        iconName: iconToSave,
                        spaceId: spaceId
                    )
                    onCreated(created)
                }
                .fontWeight(.bold)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Space Icon Helper
public struct ShareSpaceIconView: View {
    public let icon: String
    public let color: Color
    public var size: CGFloat = 16
    
    public init(icon: String, color: Color, size: CGFloat = 16) {
        self.icon = icon
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        if icon.count == 1 || icon.unicodeScalars.first?.properties.isEmoji == true {
            Text(verbatim: icon)
                .font(.system(size: size))
        } else {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 83, 124, 247)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

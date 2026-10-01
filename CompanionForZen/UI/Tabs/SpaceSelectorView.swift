import SwiftUI
import UIKit

public enum SpaceIconPickerMode: String, CaseIterable, Identifiable {
    case zenIcons
    case emojis
    
    public var id: String { rawValue }
}

/// A specialized UITextField wrapper that directly requests and presents the native iOS Emoji keyboard.
public struct EmojiKeyboardTextField: UIViewRepresentable {
    @Binding var emoji: String
    var onEmojiChanged: ((String) -> Void)?
    
    public init(emoji: Binding<String>, onEmojiChanged: ((String) -> Void)? = nil) {
        self._emoji = emoji
        self.onEmojiChanged = onEmojiChanged
    }
    
    public class EmojiUITextField: UITextField {
        override public var textInputMode: UITextInputMode? {
            for mode in UITextInputMode.activeInputModes {
                if mode.primaryLanguage == "emoji" {
                    return mode
                }
            }
            return super.textInputMode
        }
        
        override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if action == #selector(paste(_:)) {
                return true
            }
            return false
        }
    }
    
    public func makeUIView(context: Context) -> EmojiUITextField {
        let field = EmojiUITextField()
        field.tintColor = .clear
        field.font = UIFont.systemFont(ofSize: 46)
        field.textAlignment = .center
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Auto-focus immediately to pop up the emoji keyboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            field.becomeFirstResponder()
        }
        return field
    }
    
    public func updateUIView(_ uiView: EmojiUITextField, context: Context) {
        uiView.text = emoji
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboardTextField
        
        init(_ parent: EmojiKeyboardTextField) {
            self.parent = parent
        }
        
        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            
            parent.emoji = trimmed
            parent.onEmojiChanged?(trimmed)
            Haptics.selection()
            return false
        }
    }
}

/// Dedicated full screen view for selecting an icon or emoji for a Space or Folder.
public struct SpaceIconSelectionView: View {
    @Binding public var selectedIcon: String
    public var accentColor: Color
    public var showNavigationTitle: Bool
    @State private var iconPickerMode: SpaceIconPickerMode = .zenIcons
    
    public init(selectedIcon: Binding<String>, accentColor: Color, showNavigationTitle: Bool = true) {
        self._selectedIcon = selectedIcon
        self.accentColor = accentColor
        self.showNavigationTitle = showNavigationTitle
        self._iconPickerMode = State(initialValue: ZenSpaceIcons.isEmoji(selectedIcon.wrappedValue) ? .emojis : .zenIcons)
    }
    
    @ViewBuilder
    public var body: some View {
        let content = VStack(spacing: 16) {
            // Mode Picker
            Picker(selection: $iconPickerMode, label: EmptyView()) {
                Text(String(localized: "zen_icons", bundle: .main)).tag(SpaceIconPickerMode.zenIcons)
                Text(String(localized: "emojis", bundle: .main)).tag(SpaceIconPickerMode.emojis)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .onChange(of: iconPickerMode) { _, newMode in
                if newMode == .emojis && !ZenSpaceIcons.isEmoji(selectedIcon) {
                    selectedIcon = "🚀"
                } else if newMode == .zenIcons && ZenSpaceIcons.isEmoji(selectedIcon) {
                    selectedIcon = "rocket"
                }
            }
            
            if iconPickerMode == .zenIcons {
                // Zen SVG Icons (Full Catalog in neutral tones, only selected item highlights with accent)
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 14) {
                        ForEach(ZenSpaceIcons.all, id: \.self) { icon in
                            let isSelected = selectedIcon == icon || selectedIcon == "space_icon_\(icon)"
                            Button(action: {
                                Haptics.selection()
                                selectedIcon = icon
                            }) {
                                VStack(spacing: 4) {
                                    SpaceIconView(
                                        icon: icon,
                                        color: isSelected ? .white : .primary,
                                        size: 24
                                    )
                                    .frame(width: 54, height: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(isSelected ? accentColor : Color.primary.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
                                    )
                                    .shadow(color: isSelected ? accentColor.opacity(0.35) : .clear, radius: 4, x: 0, y: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            } else {
                // Emoji Keyboard Screen
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(accentColor.opacity(0.12))
                                .frame(width: 104, height: 104)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(accentColor, lineWidth: 3)
                                )
                                .shadow(color: accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                            
                            EmojiKeyboardTextField(emoji: $selectedIcon) { newEmoji in
                                selectedIcon = newEmoji
                            }
                            .frame(width: 84, height: 84)
                        }
                        
                        Text(String(localized: "choose_emoji_keyboard", bundle: .main))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        
        if showNavigationTitle {
            content
                .navigationTitle(String(localized: "space_icon_title", bundle: .main))
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

/// Horizontal Space / Workspace selector inspired by Zen Browser Spaces.
public struct SpaceSelectorView: View {
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @StateObject private var themePickerModel = ThemePickerViewModel()
    
    @State private var showingAddSpaceSheet: Bool = false
    @State private var newSpaceName: String = ""
    @State private var selectedIcon: String = "rocket"
    @State private var selectedProfile: String = "Personnel"
    @State private var customProfileName: String = ""
    @State private var editingSpace: Space? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabManager.spaces) { space in
                    let isSelected = space.id == tabManager.activeSpaceId
                    let spaceColor = space.primaryColor
                    
                    Button(action: {
                        Haptics.selection()
                        tabManager.selectSpace(space)
                    }) {
                        HStack(spacing: 6) {
                            SpaceIconView(
                                icon: space.iconName,
                                color: isSelected ? .white : spaceColor,
                                size: 14
                            )
                            
                            Text(space.name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? AnyShapeStyle(space.gradientBackground) : AnyShapeStyle(Color.primary.opacity(0.06)))
                        )
                        .shadow(color: isSelected ? space.primaryColor.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingSpace = space
                            showingAddSpaceSheet = true
                        } label: {
                            Label(String(localized: "edit_space", bundle: .main), systemImage: "pencil")
                        }
                        
                        if tabManager.spaces.count > 1 {
                            Button(role: .destructive) {
                                tabManager.deleteSpace(space)
                            } label: {
                                Label(String(localized: "delete_space", bundle: .main), systemImage: "trash")
                            }
                        }
                    }
                }
                
                // Add Space Button (+)
                Button(action: {
                    Haptics.light()
                    editingSpace = nil
                    showingAddSpaceSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showingAddSpaceSheet) {
            SpaceEditorSheet(space: editingSpace)
        }
    }
}

/// Renders either an emoji or a Zen space vector icon asset / SF Symbol.
public struct SpaceIconView: View {
    public var icon: String
    public var color: Color
    public var size: CGFloat
    
    public init(icon: String, color: Color = .primary, size: CGFloat = 18) {
        self.icon = icon
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        if ZenSpaceIcons.isEmoji(icon) {
            Text(icon)
                .font(.system(size: size))
        } else {
            let assetName = icon.hasPrefix("space_icon_") ? icon : "space_icon_\(icon)"
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(color)
            } else {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(color)
            }
        }
    }
}

/// Catalog of official Zen Space icons and emoji validation helper.
public struct ZenSpaceIcons {
    public static func isEmoji(_ str: String) -> Bool {
        guard !str.isEmpty else { return false }
        if ZenSpaceIcons.all.contains(str) || str.hasPrefix("space_icon_") {
            return false
        }
        if str.contains(where: { ("a"..."z").contains($0) || ("A"..."Z").contains($0) || $0 == "-" || $0 == "_" }) {
            return false
        }
        return str.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation ||
            (scalar.properties.isEmoji && scalar.value > 0x2380)
        }
    }
    
    public static let all: [String] = [
        "airplane", "american-football", "baseball", "basket", "bed", "bell",
        "book", "bookmark", "briefcase", "brush", "bug", "build", "cafe", "call",
        "card", "chat", "checkbox", "circle", "cloud", "code", "coins", "construct",
        "cutlery", "egg", "extension-puzzle", "eye", "fast-food", "fish", "flag",
        "flame", "flask", "folder", "game-controller", "globe-1", "globe",
        "grid-2x2", "grid-3x3", "heart", "ice-cream", "image", "inbox", "key",
        "layers", "leaf", "lightning", "location", "lock-closed", "logo-github",
        "logo-rss", "logo-usd", "mail", "map", "megaphone", "moon", "music",
        "navigate", "nuclear", "page", "palette", "paw", "people", "pizza",
        "planet", "present", "rocket", "school", "shapes", "shirt", "skull",
        "square", "squares", "star-1", "star", "stats-chart", "sun", "tada",
        "terminal", "ticket", "time", "trash", "triangle", "video", "volume-high",
        "wallet", "warning", "water", "weight"
    ]
}

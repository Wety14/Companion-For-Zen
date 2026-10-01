import SwiftUI

/// A dedicated, reusable modal sheet for creating a new Space or modifying an existing Space.
/// Provides live preview, name editing, profile assignment, icon/emoji picker, and dynamic Zen gradient customization.
public struct SpaceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @StateObject private var themePickerModel = ThemePickerViewModel()
    
    public var space: Space? // nil for new space, non-nil for editing
    public var onSaved: ((Space) -> Void)? = nil
    
    @State private var spaceName: String = ""
    @State private var selectedIcon: String = "rocket"
    @State private var selectedProfile: String = "Personnel"
    @State private var customProfileName: String = ""
    @State private var showingDeleteConfirmation: Bool = false
    
    public init(space: Space? = nil, onSaved: ((Space) -> Void)? = nil) {
        self.space = space
        self.onSaved = onSaved
    }
    
    private var isEditing: Bool {
        space != nil
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1. Live Space Preview with Dynamic Zen Gradient
                Section {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            SpaceIconView(icon: selectedIcon, color: .white, size: 18)
                            
                            Text(spaceName.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "space_name_label", bundle: .main) : spaceName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(themePickerModel.previewGradient)
                                .shadow(color: themePickerModel.primaryColor.opacity(0.35), radius: 8, x: 0, y: 4)
                        )
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - 2. Space Name
                Section(header: Text(String(localized: "space_name_label", bundle: .main))) {
                    TextField(String(localized: "space_name_placeholder", bundle: .main), text: $spaceName)
                }
                
                // MARK: - 3. Space Profile
                Section(header: Text(String(localized: "zen_profile", bundle: .main)), footer: Text(String(localized: "zen_profile_desc", bundle: .main))) {
                    Picker(String(localized: "profile_label", bundle: .main), selection: $selectedProfile) {
                        Text(String(localized: "profile_personal", bundle: .main)).tag("Personnel")
                        Text(String(localized: "profile_work", bundle: .main)).tag("Travail")
                        Text(String(localized: "profile_leisure", bundle: .main)).tag("Détente")
                        Text(String(localized: "profile_other", bundle: .main)).tag("Autre")
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedProfile == "Autre" {
                        TextField(String(localized: "profile_name_placeholder", bundle: .main), text: $customProfileName)
                    }
                }
                
                // MARK: - 4. Icon & Gradient Customization
                Section(header: Text("customization_section")) {
                    NavigationLink {
                        SpaceIconSelectionView(
                            selectedIcon: $selectedIcon,
                            accentColor: themePickerModel.primaryColor
                        )
                    } label: {
                        HStack(spacing: 12) {
                            SpaceIconView(
                                icon: selectedIcon,
                                color: themePickerModel.primaryColor,
                                size: 18
                            )
                            .frame(width: 32, height: 32)
                            .background(themePickerModel.primaryColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            
                            Text("space_icon_title")
                                .font(.body)
                            
                            Spacer()
                            
                            if ZenSpaceIcons.isEmoji(selectedIcon) {
                                Text(selectedIcon)
                                    .font(.system(size: 18))
                            } else {
                                Text(selectedIcon)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink {
                        SpaceThemePickerDetailView(model: themePickerModel)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(themePickerModel.previewGradient)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                .shadow(color: themePickerModel.primaryColor.opacity(0.25), radius: 3, x: 0, y: 1)
                            
                            Text("gradient_and_theme")
                                .font(.body)
                            
                            Spacer()
                            
                            Text(themePickerModel.scheme.label)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - 5. Delete Space
                if isEditing, tabManager.spaces.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label(String(localized: "delete_this_space", bundle: .main), systemImage: "trash")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "edit_space", bundle: .main) : String(localized: "new_space", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel", bundle: .main)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? String(localized: "save", bundle: .main) : String(localized: "create", bundle: .main)) {
                        saveSpace()
                    }
                    .disabled(spaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog(
            String(localized: "delete_space", bundle: .main),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(format: String(localized: "delete_space_named_format", bundle: .main), spaceName), role: .destructive) {
                if let existing = space {
                    Haptics.success()
                    tabManager.deleteSpace(existing)
                    dismiss()
                }
            }
            Button(String(localized: "cancel", bundle: .main), role: .cancel) {}
        } message: {
            Text(String(localized: "delete_space_warning", bundle: .main))
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        if let existing = space {
            spaceName = existing.name
            selectedIcon = existing.iconName
            if existing.profileId == "Personnel" || existing.profileId == "Travail" || existing.profileId == "Détente" {
                selectedProfile = existing.profileId
                customProfileName = ""
            } else {
                selectedProfile = "Autre"
                customProfileName = existing.profileId
            }
            themePickerModel.loadFromSpace(existing)
        } else {
            selectedIcon = "rocket"
            selectedProfile = "Personnel"
            customProfileName = ""
            themePickerModel.applySplitComplementary(fromPrimaryRGB: (83, 124, 247), lightness: 60)
        }
    }
    
    private func saveSpace() {
        let trimmedName = spaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let effectiveProfile = selectedProfile == "Autre"
            ? (customProfileName.trimmingCharacters(in: .whitespaces).isEmpty ? "Personnel" : customProfileName.trimmingCharacters(in: .whitespaces))
            : selectedProfile
        
        if let existing = space {
            tabManager.updateSpace(
                id: existing.id,
                name: trimmedName,
                iconName: selectedIcon,
                profileId: effectiveProfile,
                gradientColorsHex: themePickerModel.gradientColorsHex,
                gradientOpacity: themePickerModel.opacity,
                gradientTexture: themePickerModel.texture,
                gradientScheme: themePickerModel.scheme.rawValue
            )
            if let updated = tabManager.spaces.first(where: { $0.id == existing.id }) {
                onSaved?(updated)
            }
        } else {
            let created = tabManager.addSpace(
                name: trimmedName,
                iconName: selectedIcon,
                profileId: effectiveProfile,
                colorHex: themePickerModel.primaryColorHex,
                gradientColorsHex: themePickerModel.gradientColorsHex,
                gradientOpacity: themePickerModel.opacity,
                gradientTexture: themePickerModel.texture,
                gradientScheme: themePickerModel.scheme.rawValue
            )
            onSaved?(created)
        }
        
        Haptics.success()
        dismiss()
    }
}

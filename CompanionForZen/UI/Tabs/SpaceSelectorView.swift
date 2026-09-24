import SwiftUI

/// Horizontal Space / Workspace selector inspired by Zen Browser Spaces.
public struct SpaceSelectorView: View {
    @ObservedObject var tabManager = TabManager.shared
    @State private var showingAddSpaceSheet: Bool = false
    @State private var newSpaceName: String = ""
    @State private var selectedIcon: String = "briefcase"
    @State private var selectedColorHex: String = "#537CF7"
    
    let icons = ["person.crop.circle", "briefcase", "sparkles", "book", "gamecontroller", "star", "tag", "cart"]
    let colors = ["#537CF7", "#F76F53", "#2A9D8F", "#E76F51", "#A06CD5", "#3A86FF"]
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabManager.spaces) { space in
                    let isSelected = space.id == tabManager.activeSpaceId
                    let spaceColor = Color(hex: space.themeColorHex)
                    
                    Button(action: {
                        Haptics.selection()
                        tabManager.selectSpace(space)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: space.iconName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isSelected ? .white : spaceColor)
                            
                            Text(space.name)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? spaceColor : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Add Space Button (+)
                Button(action: {
                    Haptics.light()
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
            NavigationStack {
                Form {
                    Section("Nom de l'Espace") {
                        TextField("Ex: Recherche, Projets...", text: $newSpaceName)
                    }
                    
                    Section("Icône") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(selectedIcon == icon ? Color(hex: selectedColorHex) : .secondary)
                                            .padding(8)
                                            .background(selectedIcon == icon ? Color.primary.opacity(0.1) : Color.clear)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("Couleur d'accent") {
                        HStack(spacing: 14) {
                            ForEach(colors, id: \.self) { colorHex in
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColorHex == colorHex ? 2.5 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorHex = colorHex
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Nouvel Espace")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { showingAddSpaceSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Créer") {
                            guard !newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            tabManager.addSpace(name: newSpaceName, iconName: selectedIcon, colorHex: selectedColorHex)
                            newSpaceName = ""
                            showingAddSpaceSheet = false
                        }
                        .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

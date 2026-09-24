import SwiftUI

/// Archive view showing tabs that were automatically or manually archived.
/// Lets the user search, restore, or permanently remove old tabs.
public struct ArchivedTabsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    @State private var searchText: String = ""
    @State private var showingClearConfirmation: Bool = false
    
    public var body: some View {
        NavigationStack {
            Group {
                if filteredTabs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text(searchText.isEmpty ? "Aucun onglet archivé" : "Aucun résultat trouvé")
                            .font(.headline)
                        
                        Text("Les onglets inactifs sont automatiquement rangés ici pour garder votre espace propre et zen.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTabs) { tab in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tab.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 6) {
                                        Text(tab.displayHost)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let archivedDate = tab.archivedAt {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(archivedDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    Haptics.light()
                                    tabManager.restoreArchivedTab(tab)
                                    dismiss()
                                }) {
                                    Text(tr("restore_tab"))
                                        .font(.caption.bold())
                                        .foregroundColor(themeManager.accentColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(themeManager.accentColor.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    tabManager.deleteArchivedTab(tab)
                                } label: {
                                    Label(tr("delete_tab"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher dans les archives...")
            .navigationTitle(tr("archived_tabs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                if !tabManager.archivedTabs.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(tr("clear_all")) {
                            showingClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                "Supprimer tous les onglets archivés ?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) {
                    tabManager.clearAllArchivedTabs()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }
    
    private var filteredTabs: [Tab] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return tabManager.archivedTabs
        }
        return tabManager.archivedTabs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }
}

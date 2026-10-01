import SwiftUI

/// Archive view showing tabs that were automatically or manually archived.
/// Lets the user search, restore, or permanently remove old tabs.
public struct ArchivedTabsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
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
                        
                        Text(searchText.isEmpty ? String(localized: "no_archived_tabs", bundle: .main) : String(localized: "no_results_found", bundle: .main))
                            .font(.headline)
                        
                        Text(String(localized: "archive_empty_desc", bundle: .main))
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
                                            Text("bullet_separator")
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
                                    Text(String(localized: "restore_tab", bundle: .main))
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
                                    Label(String(localized: "delete_tab", bundle: .main), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: String(localized: "search_archive_prompt", bundle: .main))
            .navigationTitle(String(localized: "archived_tabs", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close", bundle: .main)) { dismiss() }
                }
                if !tabManager.archivedTabs.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(String(localized: "clear_all", bundle: .main)) {
                            showingClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                String(localized: "delete_all_archived_confirmation", bundle: .main),
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "clear_all", bundle: .main), role: .destructive) {
                    tabManager.clearAllArchivedTabs()
                }
                Button(String(localized: "cancel", bundle: .main), role: .cancel) {}
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

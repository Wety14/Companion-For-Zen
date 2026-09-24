import SwiftUI

/// Browsing history list view with search and clear operations.
public struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    @State private var searchText: String = ""
    @State private var showingClearConfirmation: Bool = false
    
    public var onSelectURL: (URL) -> Void
    
    public var body: some View {
        Group {
                if filteredHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text(tr("no_history"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredHistory) { entry in
                            Button(action: {
                                onSelectURL(entry.url)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    HStack {
                                        Text(entry.url.host ?? entry.url.absoluteString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text(entry.visitedAt, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    historyService.deleteEntry(entry)
                                } label: {
                                    Label(tr("delete_tab"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher dans l'historique...")
            .navigationTitle(tr("history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !historyService.historyEntries.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(tr("clear_history")) {
                            showingClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                "Effacer tout l'historique de navigation ?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) {
                    historyService.clearAll()
                }
                Button("Annuler", role: .cancel) {}
            }
    }
    
    private var filteredHistory: [HistoryEntry] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return historyService.historyEntries
        }
        return historyService.historyEntries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }
}

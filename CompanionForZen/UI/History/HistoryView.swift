import SwiftUI

/// Browsing history list view with search and clear operations.
public struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var historyService = HistoryService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
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
                        
                        Text(String(localized: "no_history", bundle: .main))
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
                                    Label(String(localized: "delete_tab", bundle: .main), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: String(localized: "search_history_prompt", bundle: .main))
            .navigationTitle(String(localized: "history", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !historyService.historyEntries.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(String(localized: "clear_history", bundle: .main)) {
                            showingClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .confirmationDialog(
                String(localized: "clear_history_confirmation", bundle: .main),
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "clear_all", bundle: .main), role: .destructive) {
                    historyService.clearAll()
                }
                Button(String(localized: "cancel", bundle: .main), role: .cancel) {}
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

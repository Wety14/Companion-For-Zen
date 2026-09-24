import SwiftUI

/// Tab Drawer view showing Spaces, Pinned Tabs, Today Tabs, and the Archive access.
public struct TabDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    @State private var showingArchiveSheet: Bool = false
    public var onOpenSearch: (() -> Void)? = nil
    
    public init(onOpenSearch: (() -> Void)? = nil) {
        self.onOpenSearch = onOpenSearch
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Spaces Horizontal Selector
                SpaceSelectorView()
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let currentSpaceId = tabManager.activeSpaceId
                        let pinned = tabManager.pinnedTabs(for: currentSpaceId)
                        let today = tabManager.todayTabs(for: currentSpaceId)
                        
                        // Pinned Tabs Section
                        if !pinned.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundColor(themeManager.accentColor)
                                    Text(tr("pinned_tabs"))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(pinned) { tab in
                                    TabCardView(
                                        tab: tab,
                                        isActive: tab.id == tabManager.activeTabId,
                                        onSelect: {
                                            tabManager.selectTab(tab)
                                            dismiss()
                                        },
                                        onClose: {
                                            tabManager.closeTab(tabId: tab.id)
                                        },
                                        onTogglePin: {
                                            tabManager.togglePin(tabId: tab.id)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Today's Active Tabs Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(tr("today_tabs"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text("\(today.count) ouverts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            
                            if today.isEmpty && pinned.isEmpty {
                                VStack(spacing: 12) {
                                    Text("Aucun onglet ouvert dans cet espace")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 24)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(today) { tab in
                                    TabCardView(
                                        tab: tab,
                                        isActive: tab.id == tabManager.activeTabId,
                                        onSelect: {
                                            tabManager.selectTab(tab)
                                            dismiss()
                                        },
                                        onClose: {
                                            tabManager.closeTab(tabId: tab.id)
                                        },
                                        onTogglePin: {
                                            tabManager.togglePin(tabId: tab.id)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Archived Tabs Banner
                        if !tabManager.archivedTabs.isEmpty {
                            Button(action: {
                                Haptics.light()
                                showingArchiveSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "archivebox.fill")
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tr("archived_tabs"))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("\(tabManager.archivedTabs.count) onglets archivés automatiquement")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                }
                
                // Bottom Action Bar (+ New Tab)
                HStack {
                    Button(action: {
                        Haptics.light()
                        tabManager.performAutoArchiveCheck()
                    }) {
                        Label(tr("archive_now"), systemImage: "clock.arrow.circlepath")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Haptics.medium()
                        dismiss()
                        if let onOpenSearch = onOpenSearch {
                            onOpenSearch()
                        } else {
                            tabManager.openNewTab()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text(tr("new_tab"))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        .clipShape(Capsule())
                        .shadow(color: themeManager.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(tabManager.activeSpace.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("OK") { dismiss() }
                        .font(.body.bold())
                        .foregroundColor(themeManager.accentColor)
                }
            }
            .sheet(isPresented: $showingArchiveSheet) {
                ArchivedTabsView()
            }
        }
    }
}

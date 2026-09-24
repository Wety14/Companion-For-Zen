import SwiftUI

/// Firefox Sync (Mozilla Sync 1.5) account and synchronization management view
/// offering a true 1:1 twin representation of Zen Browser Desktop's sidebar.
public struct FirefoxSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService = FirefoxSyncService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var tabManager = TabManager.shared
    
    public var onSelectURL: ((URL) -> Void)?
    
    @State private var emailInput: String = ""
    @State private var showMirrorSuccessAlert: Bool = false
    
    public init(onSelectURL: ((URL) -> Void)? = nil) {
        self.onSelectURL = onSelectURL
    }
    
    public var body: some View {
        List {
            // Account Section
            Section {
                if syncService.isConnected {
                    HStack(spacing: 16) {
                        ZenLogoView(size: 44, showBackground: true, backgroundColor: themeManager.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr("connected_as"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(syncService.userEmail ?? "")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let lastSync = syncService.lastSyncDate {
                                Text("\(tr("last_synced")) \(lastSync, style: .time)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        Haptics.medium()
                        syncService.triggerSync()
                    }) {
                        HStack {
                            if syncService.status == .syncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Synchronisation en cours...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(tr("sync_now"))
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Synchronisez avec Zen Desktop")
                            .font(.headline)
                        
                        Text("Connectez votre compte Firefox pour retrouver vos favoris, votre historique et la réplique exacte de votre sidebar Zen Desktop.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Adresse e-mail Firefox Account", text: $emailInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            guard !emailInput.isEmpty else { return }
                            Haptics.medium()
                            syncService.connectAccount(email: emailInput) { _ in }
                        }) {
                            HStack {
                                Spacer()
                                if syncService.status == .connecting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(tr("sign_in_mozilla"))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(themeManager.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(emailInput.isEmpty || syncService.status == .connecting)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("Compte")
            }
            
            // True Twin Sidebar Section (Représentation jumelle de la Sidebar Zen Desktop)
            if syncService.isConnected {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(themeManager.accentColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "laptopcomputer.and.iphone")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(themeManager.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Jumelage Sidebar Desktop")
                                    .font(.system(size: 16, weight: .bold))
                                Text(tr("desktop_sidebar_desc"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Button to mirror full sidebar directly
                        Button(action: {
                            Haptics.medium()
                            syncService.mirrorDesktopSidebarToLocal(tabManager: tabManager)
                            showMirrorSuccessAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(tr("mirror_sidebar_now"))
                                    .font(.system(size: 14, weight: .bold))
                                Spacer()
                            }
                            .padding(.vertical, 11)
                            .foregroundColor(.white)
                            .background(themeManager.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        Toggle("Jumelage automatique continu", isOn: Binding(
                            get: { syncService.autoMirrorSidebar },
                            set: { syncService.setAutoMirror($0) }
                        ))
                        .tint(themeManager.accentColor)
                        .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Jumelage Sidebar Zen Desktop")
                }
                
                // Display each Desktop Workspace Twin with its exact colors, pinned tabs & open tabs
                if let sidebar = syncService.desktopSidebar, !sidebar.workspaces.isEmpty {
                    Section {
                        ForEach(sidebar.workspaces) { ws in
                            DisclosureGroup {
                                // Pinned tabs in this desktop workspace
                                if !ws.pinnedTabs.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "pin.fill")
                                                .font(.caption2)
                                                .foregroundColor(Color(hex: ws.themeColorHex))
                                            Text("Onglets épinglés")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .textCase(.uppercase)
                                        }
                                        .padding(.top, 4)
                                        
                                        ForEach(ws.pinnedTabs) { pTab in
                                            Button(action: {
                                                handleTabSelection(url: pTab.url)
                                            }) {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "pin")
                                                        .font(.caption)
                                                        .foregroundColor(Color(hex: ws.themeColorHex))
                                                    Text(pTab.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(pTab.url.host ?? "")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                                
                                // Open tabs in this desktop workspace
                                if !ws.openTabs.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "safari")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("Onglets ouverts (\(ws.openTabs.count))")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .textCase(.uppercase)
                                        }
                                        .padding(.top, 4)
                                        
                                        ForEach(ws.openTabs) { oTab in
                                            Button(action: {
                                                handleTabSelection(url: oTab.url)
                                            }) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(oTab.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Text(oTab.url.host ?? oTab.url.absoluteString)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.vertical, 3)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: ws.themeColorHex))
                                        .frame(width: 14, height: 14)
                                    
                                    Image(systemName: ws.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: ws.themeColorHex))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name)
                                            .font(.system(size: 15, weight: .bold))
                                        Text("\(ws.pinnedTabs.count) épinglés · \(ws.openTabs.count) ouverts")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Espaces Desktop Synchronisés (\(sidebar.workspaces.count))")
                    }
                }
                
                // Synced Collections Toggles
                Section("Options de synchronisation") {
                    Toggle(tr("sync_tabs"), isOn: $syncService.syncTabs)
                        .tint(themeManager.accentColor)
                    Toggle(tr("sync_bookmarks"), isOn: $syncService.syncBookmarks)
                        .tint(themeManager.accentColor)
                    Toggle(tr("sync_history"), isOn: $syncService.syncHistory)
                        .tint(themeManager.accentColor)
                }
                
                Section {
                    Button(tr("sign_out"), role: .destructive) {
                        syncService.disconnect()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tr("firefox_sync"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sidebar Desktop Jumelée !", isPresented: $showMirrorSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Tous vos espaces, couleurs de thème, onglets épinglés et onglets ouverts de Zen Desktop ont été appliqués avec succès à votre Zen Browser iOS.")
        }
    }
    
    private func handleTabSelection(url: URL) {
        tabManager.openNewTab(url: url)
        if let onSelectURL = onSelectURL {
            onSelectURL(url)
        }
        dismiss()
    }
}

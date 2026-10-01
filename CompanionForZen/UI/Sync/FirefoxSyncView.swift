import SwiftUI

/// Firefox Sync (Mozilla Sync 1.5) account and synchronization management view
/// offering a true 1:1 twin representation of Zen Browser Desktop's sidebar.
public struct FirefoxSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService = FirefoxSyncService.shared
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var tabManager = TabManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    public var onSelectURL: ((URL) -> Void)?
    
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var errorMessage: String? = nil
    
    @State private var showingFirstSyncDialog: Bool = false
    @State private var showingQRScanner: Bool = false
    @State private var showingResetConfirmation: Bool = false
    
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
                            Text(String(localized: "connected_as", bundle: .main))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(syncService.userEmail ?? "")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let lastSync = syncService.lastSyncDate {
                                Text("\(String(localized: "last_synced", bundle: .main)) \(lastSync, style: .time)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        Haptics.medium()
                        if !syncService.hasPromptedFirstSyncPriority {
                            showingFirstSyncDialog = true
                        } else {
                            syncService.triggerSync()
                        }
                    }) {
                        HStack {
                            if syncService.status == .syncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("syncing")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(String(localized: "sync_now", bundle: .main))
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                    }
                    
                    Button(action: {
                        Haptics.medium()
                        showingQRScanner = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                            Text("qr_code_login")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(themeManager.accentColor)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "sync_with_zen_desktop", bundle: .main))
                            .font(.headline)
                        
                        Text(String(localized: "sync_desktop_desc", bundle: .main))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Fast QR Code pairing card
                        Button(action: {
                            Haptics.medium()
                            showingQRScanner = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 22, weight: .bold))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("qr_code_login")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("scan_qr_instruction")
                                        .font(.system(size: 11.5))
                                        .opacity(0.85)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .opacity(0.7)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(themeManager.accentColor.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: themeManager.accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(height: 1)
                            Text("or_with_credentials")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 2)
                        
                        VStack(spacing: 10) {
                            TextField(String(localized: "firefox_email_placeholder", bundle: .main), text: $emailInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                if isPasswordVisible {
                                    TextField(String(localized: "password", bundle: .main), text: $passwordInput)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField(String(localized: "password", bundle: .main), text: $passwordInput)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                                
                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(localized: "firefox_e2ee_notice", bundle: .main))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            guard !emailInput.isEmpty && !passwordInput.isEmpty else { return }
                            Haptics.medium()
                            errorMessage = nil
                            syncService.connectAccount(email: emailInput, password: passwordInput) { result in
                                switch result {
                                case .success:
                                    passwordInput = ""
                                    if !syncService.hasPromptedFirstSyncPriority {
                                        showingFirstSyncDialog = true
                                    }
                                case .failure(let err):
                                    errorMessage = err.localizedDescription
                                }
                            }
                        }) {
                            HStack {
                                Spacer()
                                if syncService.status == .connecting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(String(localized: "sign_in_mozilla", bundle: .main))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(themeManager.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(emailInput.isEmpty || passwordInput.isEmpty || syncService.status == .connecting)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("account")
            }
            
            if syncService.isConnected {
                
                // Workspaces Mirror Details
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
                                            Text(String(format: String(localized: "pinned_tabs_count_format", bundle: .main), ws.pinnedTabs.count))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .textCase(.uppercase)
                                        }
                                        .padding(.top, 4)
                                        
                                        ForEach(ws.pinnedTabs) { pTab in
                                            Button(action: {
                                                handleTabSelection(url: pTab.url)
                                            }) {
                                                HStack {
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
                                            Text(String(format: String(localized: "open_tabs_count_format", bundle: .main), ws.openTabs.count))
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
                                    
                                    SpaceIconView(
                                        icon: ws.iconName,
                                        color: Color(hex: ws.themeColorHex),
                                        size: 16
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ws.name)
                                            .font(.system(size: 15, weight: .bold))
                                        Text(String(format: String(localized: "pinned_open_count_format", bundle: .main), ws.pinnedTabs.count, ws.openTabs.count))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text(String(format: String(localized: "synced_desktop_spaces_format", bundle: .main), sidebar.workspaces.count))
                    }
                }
                
                // Synced Collections Toggles
                Section(String(localized: "sync_options", bundle: .main)) {
                    Picker(String(localized: "sync_priority", bundle: .main), selection: Binding(
                        get: { syncService.firstSyncPriority },
                        set: { syncService.setFirstSyncPriority($0) }
                    )) {
                        ForEach(FirstSyncPriority.allCases, id: \.self) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    Toggle(String(localized: "sync_tabs", bundle: .main), isOn: $syncService.syncTabs)
                        .tint(themeManager.accentColor)
                    Toggle(String(localized: "sync_bookmarks", bundle: .main), isOn: $syncService.syncBookmarks)
                        .tint(themeManager.accentColor)
                    Toggle(String(localized: "sync_history", bundle: .main), isOn: $syncService.syncHistory)
                        .tint(themeManager.accentColor)
                }
                
                // Cache Purge & Clean Reset
                Section {
                    Button(role: .destructive, action: {
                        showingResetConfirmation = true
                    }) {
                        Label(String(localized: "purge_cache_reset", bundle: .main), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } footer: {
                    Text("reset_spaces_desc")
                }
                
                Section {
                    Button(String(localized: "sign_out", bundle: .main), role: .destructive) {
                        syncService.disconnect()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "firefox_sync", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
                .confirmationDialog(
            String(localized: "purge_cache_reset_confirm", bundle: .main),
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "reset_spaces_cache", bundle: .main), role: .destructive) {
                syncService.clearAllSyncedData(resetLocalTabs: true)
            }
            Button(String(localized: "purge_remote_cache_only", bundle: .main), role: .destructive) {
                syncService.clearAllSyncedData(resetLocalTabs: false)
            }
            Button(String(localized: "cancel", bundle: .main), role: .cancel) { }
        } message: {
            Text("purge_cache_desc")
        }
        .confirmationDialog(
            String(localized: "first_sync_title", bundle: .main),
            isPresented: $showingFirstSyncDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "replace_with_zen_desktop", bundle: .main)) {
                syncService.setFirstSyncPriority(.desktopPriority)
                syncService.triggerSync(forcedPriority: .desktopPriority)
            }
            Button(String(localized: "keep_phone_content", bundle: .main)) {
                syncService.setFirstSyncPriority(.mobilePriority)
                syncService.triggerSync(forcedPriority: .mobilePriority)
            }
            Button(String(localized: "smart_merge", bundle: .main)) {
                syncService.setFirstSyncPriority(.merge)
                syncService.triggerSync(forcedPriority: .merge)
            }
            Button(String(localized: "cancel", bundle: .main), role: .cancel) { }
        } message: {
            Text("sync_conflict_message")
        }
        .sheet(isPresented: $showingQRScanner) {
            QRCodeScannerView { scannedCode in
                handleScannedQRCode(scannedCode)
            }
        }
    }
    
    private func handleScannedQRCode(_ scannedCode: String) {
        syncService.connectViaQRCode(scannedCode: scannedCode) { result in
            switch result {
            case .success:
                errorMessage = nil
                if !syncService.hasPromptedFirstSyncPriority {
                    showingFirstSyncDialog = true
                } else {
                    syncService.triggerSync()
                }
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }
    
    private func handleTabSelection(url: URL) {
        if let onSelectURL = onSelectURL {
            onSelectURL(url)
        } else {
            tabManager.openNewTab(url: url)
        }
        dismiss()
    }
}

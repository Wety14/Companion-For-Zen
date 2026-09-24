import SwiftUI

/// App Icon selection view allowing users to pick between official Zen icon themes.
public struct IconPickerView: View {
    @ObservedObject var themeManager = ZenThemeManager.shared
    @State private var selectedIcon: AppIconOption = .twilight
    
    public var body: some View {
        List {
            Section {
                ForEach(AppIconOption.allCases) { option in
                    Button(action: {
                        Haptics.selection()
                        selectedIcon = option
                        setAppIcon(option)
                    }) {
                        HStack(spacing: 16) {
                            ZenLogoView(
                                size: 52,
                                showBackground: true,
                                backgroundColor: option.iconColor
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            if selectedIcon == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("L'icône de l'application sur votre écran d'accueil changera selon votre sélection.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tr("app_icon"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let current = UIApplication.shared.alternateIconName
            if let current = current, let match = AppIconOption(rawValue: current) {
                selectedIcon = match
            } else {
                selectedIcon = .twilight
            }
        }
    }
    
    private func setAppIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            if let error = error {
                print("Error setting icon: \(error.localizedDescription)")
            }
        }
    }
}

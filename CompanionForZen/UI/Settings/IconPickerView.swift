import SwiftUI

/// App Icon selection view allowing users to pick between official Zen icon themes.
public struct IconPickerView: View {
    @ObservedObject var themeManager = ZenThemeManager.shared
    @State private var selectedIcon: AppIconOption = .twilight
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Live Springboard Preview Card
                VStack(spacing: 12) {
                    ZStack {
                        // Ambient glow
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(selectedIcon.iconColor.opacity(0.35))
                            .frame(width: 86, height: 86)
                            .blur(radius: 14)
                        
                        // App Icon render
                        iconImage(for: selectedIcon, size: 84, cornerRadius: 20)
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 8)
                    
                    VStack(spacing: 2) {
                        Text("Zen Browser")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(selectedIcon.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                
                // 2x2 Grid of the 4 new official icons
                VStack(alignment: .leading, spacing: 14) {
                    Text("Icônes disponibles")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppIconOption.allCases) { option in
                            iconCard(for: option)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // Explanatory Footer Card
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("L'icône de l'application sur votre écran d'accueil iOS change instantanément dès la sélection.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(tr("app_icon"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentIcon()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func iconCard(for option: AppIconOption) -> some View {
        let isSelected = selectedIcon == option
        
        Button(action: {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedIcon = option
            }
            setAppIcon(option)
        }) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    iconImage(for: option, size: 72, cornerRadius: 17)
                        .shadow(color: Color.black.opacity(isSelected ? 0.25 : 0.1), radius: 6, x: 0, y: 3)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.accentColor)
                            .background(Circle().fill(Color.white).padding(2))
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
                
                VStack(spacing: 3) {
                    Text(option.displayName)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.primary)
                    
                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? themeManager.accentColor : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func iconImage(for option: AppIconOption, size: CGFloat, cornerRadius: CGFloat) -> some View {
        Image(option.previewImageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    // MARK: - Actions
    
    private func loadCurrentIcon() {
        let current = UIApplication.shared.alternateIconName
        if let current = current, let match = AppIconOption(rawValue: current) {
            selectedIcon = match
        } else {
            selectedIcon = .twilight
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

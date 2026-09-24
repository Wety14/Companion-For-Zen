import SwiftUI

/// Card representing a Tab in the Drawer or Grid.
public struct TabCardView: View {
    public let tab: Tab
    public var isActive: Bool
    public var onSelect: () -> Void
    public var onClose: () -> Void
    public var onTogglePin: () -> Void
    
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    public var body: some View {
        Button(action: {
            Haptics.selection()
            onSelect()
        }) {
            HStack(spacing: 12) {
                // Favicon or host letter circle
                ZStack {
                    Circle()
                        .fill(isActive ? themeManager.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 34, height: 34)
                    
                    Text(String(tab.displayHost.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(isActive ? .white : .primary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.title)
                        .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(tab.displayHost)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Pin button
                Button(action: onTogglePin) {
                    Image(systemName: tab.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 13))
                        .foregroundColor(tab.isPinned ? themeManager.accentColor : .secondary.opacity(0.5))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                
                // Close button
                Button(action: {
                    Haptics.light()
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? themeManager.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isActive ? themeManager.accentColor : Color.primary.opacity(0.06),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

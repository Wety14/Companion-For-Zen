import SwiftUI

/// Vector SwiftUI representation of the Zen Browser logo.
/// Scalable, resolution-independent, with concentric circles and optional container.
public struct ZenLogoView: View {
    public var size: CGFloat
    public var showBackground: Bool
    public var backgroundColor: Color?
    public var ringColor: Color
    public var isPulsing: Bool
    
    public init(
        size: CGFloat = 48,
        showBackground: Bool = true,
        backgroundColor: Color? = nil,
        ringColor: Color = ZenDesign.zenCream,
        isPulsing: Bool = false
    ) {
        self.size = size
        self.showBackground = showBackground
        self.backgroundColor = backgroundColor
        self.ringColor = ringColor
        self.isPulsing = isPulsing
    }
    
    public var body: some View {
        let scaleFactor = size / 1024.0
        
        ZStack {
            if showBackground {
                RoundedRectangle(cornerRadius: 155.371 * scaleFactor, style: .continuous)
                    .fill(backgroundColor ?? ZenThemeManager.shared.accentColor)
                    .frame(width: size, height: size)
                    .shadow(color: (backgroundColor ?? ZenThemeManager.shared.accentColor).opacity(0.4), radius: 10 * scaleFactor, x: 0, y: 4 * scaleFactor)
            }
            
            // Concentric Circles
            ZStack {
                // Circle 1 (Inner)
                Circle()
                    .stroke(ringColor, lineWidth: max(1.5, 25.1953 * scaleFactor))
                    .frame(width: 2 * 113.02 * scaleFactor, height: 2 * 113.02 * scaleFactor)
                
                // Circle 2 (Middle)
                Circle()
                    .stroke(ringColor, lineWidth: max(2.0, 41.9922 * scaleFactor))
                    .frame(width: 2 * 197.737 * scaleFactor, height: 2 * 197.737 * scaleFactor)
                
                // Circle 3 (Outer)
                Circle()
                    .stroke(ringColor, lineWidth: max(2.5, 58.7891 * scaleFactor))
                    .frame(width: 2 * 298.266 * scaleFactor, height: 2 * 298.266 * scaleFactor)
            }
        }
        .frame(width: size, height: size)
    }
}

import SwiftUI
import UIKit

/// ViewModifier implementing the Zen "Liquid Glass" effect:
/// Translucent ultra-thin material blur, iridescent border highlight, and soft ambient shadow.
public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeColor: Color
    public var shadowRadius: CGFloat
    
    public init(
        cornerRadius: CGFloat = ZenDesign.radiusCard,
        strokeColor: Color = Color.white.opacity(0.18),
        shadowRadius: CGFloat = 16
    ) {
        self.cornerRadius = cornerRadius
        self.strokeColor = strokeColor
        self.shadowRadius = shadowRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                strokeColor,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: shadowRadius, x: 0, y: 8)
    }
}

extension View {
    public func liquidGlass(
        cornerRadius: CGFloat = ZenDesign.radiusCard,
        strokeColor: Color = Color.white.opacity(0.18),
        shadowRadius: CGFloat = 16
    ) -> some View {
        self.modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            strokeColor: strokeColor,
            shadowRadius: shadowRadius
        ))
    }
}

/// Haptic feedback helper
public enum Haptics {
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

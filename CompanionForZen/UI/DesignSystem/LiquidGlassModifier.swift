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
    
    public static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Interactive Spring Button Style

public struct InteractiveSpringButtonStyle: ButtonStyle {
    public var pressedScale: CGFloat
    public var pressedOpacity: CGFloat
    
    public init(pressedScale: CGFloat = 0.90, pressedOpacity: CGFloat = 0.88) {
        self.pressedScale = pressedScale
        self.pressedOpacity = pressedOpacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Glass Action Buttons

public struct GlassSendButtonBackground: ViewModifier {
    public let accentColor: Color

    public init(accentColor: Color) {
        self.accentColor = accentColor
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(accentColor).interactive(),
                    in: .circle
                )
        } else {
            // Repli pour les versions antérieures à iOS 26
            content
                .background(
                    Circle()
                        .fill(accentColor.gradient)
                        .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
                )
        }
    }
}

public struct GlassSendButton: View {
    public var action: () -> Void
    public var accentColor: Color
    public var size: CGFloat
    public var systemName: String

    public init(
        action: @escaping () -> Void,
        accentColor: Color = .accentColor,
        size: CGFloat = 44,
        systemName: String = "square.and.arrow.up"
    ) {
        self.action = action
        self.accentColor = accentColor
        self.size = size
        self.systemName = systemName
    }

    public var body: some View {
        Button(action: {
            Haptics.medium()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .modifier(GlassSendButtonBackground(accentColor: accentColor))
        }
        .buttonStyle(InteractiveSpringButtonStyle())
    }
}

public struct GlassPlusButton: View {
    public var action: () -> Void
    public var accentColor: Color
    public var size: CGFloat

    public init(
        action: @escaping () -> Void,
        accentColor: Color = .accentColor,
        size: CGFloat = 44
    ) {
        self.action = action
        self.accentColor = accentColor
        self.size = size
    }

    public var body: some View {
        Button(action: {
            Haptics.medium()
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .modifier(GlassSendButtonBackground(accentColor: accentColor))
        }
        .buttonStyle(InteractiveSpringButtonStyle())
    }
}
public struct GlassGrayButtonBackground: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.interactive(),
                    in: .circle
                )
        } else {
            content
                .background(
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                )
        }
    }
}

public struct GlassCloseButton: View {
    public var action: () -> Void
    public var size: CGFloat

    public init(
        action: @escaping () -> Void,
        size: CGFloat = 44
    ) {
        self.action = action
        self.size = size
    }

    public var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .modifier(GlassGrayButtonBackground())
    }
}


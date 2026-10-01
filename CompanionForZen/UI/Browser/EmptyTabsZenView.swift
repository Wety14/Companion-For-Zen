import SwiftUI
import AudioToolbox

/// Interactive empty state view when no tabs are open.
/// - Movable Zen logo with spring return to center.
/// - Scales up smoothly when clicked or held for dragging, returning to original size on release.
/// - Concentric ripple waves on tap with randomized vibrant colors and bounce effect.
/// - Dynamic color gradient rotation on vertical swipe outside the logo, smoothly returning to white.
public struct EmptyTabsZenView: View {
    @EnvironmentObject private var locManager: LocalizationManager
    @ObservedObject private var themeManager = ZenThemeManager.shared
    
    // Logo position & dynamic scale
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingLogo: Bool = false
    @State private var logoScale: CGFloat = 1.0
    
    // Concentric ripple waves on tap
    private struct RippleWave: Identifiable {
        let id = UUID()
        let color: Color
        var scale: CGFloat
        var opacity: Double
    }
    @State private var ripples: [RippleWave] = []
    @State private var lastWaveColorIndex: Int = -1
    
    // Vibrant wave color palette (guaranteed never identical twice in a row)
    private let wavePalette: [Color] = [
        Color(red: 0.98, green: 0.35, blue: 0.65), // Vibrant Neon Pink
        Color(red: 0.25, green: 0.78, blue: 0.98), // Electric Cyan
        Color(red: 0.62, green: 0.35, blue: 0.98), // Vivid Purple
        Color(red: 0.98, green: 0.55, blue: 0.18), // Zen Coral / Orange
        Color(red: 0.22, green: 0.88, blue: 0.55), // Emerald Mint
        Color(red: 1.00, green: 0.82, blue: 0.25), // Golden Amber
        Color(red: 0.32, green: 0.52, blue: 0.98), // Royal Indigo
        Color(red: 0.18, green: 0.90, blue: 0.85)  // Bright Turquoise
    ]
    
    // Color gradient cycling state on vertical background swipe
    @State private var logoColor: Color = .white
    @State private var colorCycleTimer: Timer? = nil
    @State private var isCyclingColors: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gesture area (detects swipes outside the logo zone)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                handleBackgroundVerticalSwipe(value: value)
                            }
                    )
                
                // Concentric ripples emitted from center
                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(ripple.color, lineWidth: max(1.5, 4.0 * (1.0 - ripple.opacity * 0.5)))
                        .frame(width: 110, height: 110)
                        .scaleEffect(ripple.scale)
                        .opacity(ripple.opacity)
                        .allowsHitTesting(false)
                }
                
                // Centered Interactive Zen Logo
                ZStack {
                    // Generous invisible circular touch surface to guarantee hit detection
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 140, height: 140)
                    
                    ZenLogoView(
                        size: 110,
                        showBackground: false,
                        ringColor: logoColor
                    )
                    .shadow(
                        color: logoColor.opacity(logoColor == .white ? 0.35 : 0.65),
                        radius: isDraggingLogo ? 26 : 18,
                        x: 0,
                        y: isDraggingLogo ? 6 : 0
                    )
                }
                .contentShape(Circle())
                .scaleEffect(logoScale)
                .offset(dragOffset)
                // Logo drag gesture (scales up on press & drag, springs back to center and original size on release)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDraggingLogo {
                                isDraggingLogo = true
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                    logoScale = 1.22
                                }
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            isDraggingLogo = false
                            let dragDist = hypot(value.translation.width, value.translation.height)
                            if dragDist < 8 {
                                // Tap / click: pop bigger, send ripple wave, then spring back to original size
                                triggerLogoBounceAndRipple()
                            } else {
                                // Drag release: Spring return to center AND original size
                                Haptics.light()
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                                    dragOffset = .zero
                                    logoScale = 1.0
                                }
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDisappear {
            colorCycleTimer?.invalidate()
            colorCycleTimer = nil
        }
    }
    
    // MARK: - Logo Tap & Concentric Ripple Wave
    
    private func triggerLogoBounceAndRipple() {
        Haptics.medium()
        
        // 1. Pop bigger on click (plus gros au clic) then spring back to original size
        withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
            logoScale = 1.25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) {
                logoScale = 1.0
            }
        }
        
        // 2. Pick next color guaranteed different from the previous one
        var nextIndex = Int.random(in: 0..<wavePalette.count)
        if nextIndex == lastWaveColorIndex {
            nextIndex = (nextIndex + 1) % wavePalette.count
        }
        lastWaveColorIndex = nextIndex
        let waveColor = wavePalette[nextIndex]
        
        // 3. Spawn expanding concentric wave
        let newWave = RippleWave(
            color: waveColor,
            scale: 0.9,
            opacity: 0.95
        )
        ripples.append(newWave)
        
        withAnimation(.easeOut(duration: 1.1)) {
            if let idx = ripples.firstIndex(where: { $0.id == newWave.id }) {
                ripples[idx].scale = 4.2
                ripples[idx].opacity = 0.0
            }
        }
        
        // Clean up old waves after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            ripples.removeAll(where: { $0.id == newWave.id })
        }
    }
    
    // MARK: - Vertical Swipe Outside Logo: Gradient Color Wheel Journey
    
    private func handleBackgroundVerticalSwipe(value: DragGesture.Value) {
        let deltaY = abs(value.translation.height)
        let predictedDeltaY = abs(value.predictedEndTranslation.height)
        let intensity = max(deltaY, predictedDeltaY)
        
        // Minimum threshold to prevent accidental taps
        guard intensity > 25 else { return }
        
        Haptics.light()
        
        // Calculate number of full spectrum revolutions based on swipe intensity
        // Weak swipe: 1 cycle (1.0). Strong flick: 3-5 cycles!
        let totalCycles = max(1.2, min(5.5, Double(intensity) / 130.0))
        let totalDuration = max(1.0, min(3.8, totalCycles * 0.75))
        
        colorCycleTimer?.invalidate()
        isCyclingColors = true
        
        let startTime = Date()
        let timerInterval = 0.02
        
        colorCycleTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = elapsed / totalDuration
            
            if progress >= 1.0 {
                timer.invalidate()
                colorCycleTimer = nil
                isCyclingColors = false
                withAnimation(.easeOut(duration: 0.3)) {
                    logoColor = .white
                }
            } else {
                // Hue progresses through the color wheel
                let currentHue = (progress * totalCycles).truncatingRemainder(dividingBy: 1.0)
                
                // In the last 20% of the duration, smoothly desaturate back towards pure white
                let saturation: Double
                if progress > 0.80 {
                    let exitProgress = (progress - 0.80) / 0.20
                    saturation = (1.0 - exitProgress) * 0.90
                } else {
                    saturation = 0.90
                }
                
                let brightness: Double = 1.0
                logoColor = Color(hue: currentHue, saturation: saturation, brightness: brightness)
            }
        }
    }
}

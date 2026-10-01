import SwiftUI

// MARK: - Colour math (ported from ZenGradientGenerator.mjs)

public enum ColorMath {
    public static func hueToRgb(p: Double, q: Double, t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1 / 6 { return p + (q - p) * 6 * t }
        if t < 1 / 2 { return q }
        if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
        return p
    }

    /// h, s, l in [0, 1] → r, g, b in [0, 255]
    public static func hslToRgb(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        if s == 0 {
            return (l * 255, l * 255, l * 255)
        }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        let r = hueToRgb(p: p, q: q, t: h + 1 / 3)
        let g = hueToRgb(p: p, q: q, t: h)
        let b = hueToRgb(p: p, q: q, t: h - 1 / 3)
        return (r * 255, g * 255, b * 255)
    }

    /// r, g, b in [0, 255] → h in [0, 360], s, l in [0, 1]
    public static func rgbToHsl(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let r = r / 255, g = g / 255, b = b / 255
        let maxV = max(r, g, b), minV = min(r, g, b)
        let d = maxV - minV
        var h: Double = 0
        if d != 0 {
            if maxV == r {
                h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
            } else if maxV == g {
                h = (b - r) / d + 2
            } else {
                h = (r - g) / d + 4
            }
        }
        let l = (minV + maxV) / 2
        let s = d == 0 ? 0 : d / (1 - abs(2 * l - 1))
        return (h * 60, s, l)
    }
}

// MARK: - Model

public enum DotType {
    case standard           // saturation follows distance from centre, lightness follows drag
    case explicitLightness  // saturation is derived, lightness stays fixed
    case explicitBlackWhite // grayscale ramp only
}

public enum ColorHarmony: CaseIterable {
    case complementary, splitComplementary, floating

    public var angles: [Double] {
        switch self {
        case .complementary: return [180]
        case .splitComplementary: return [150, 210]
        case .floating: return []
        }
    }
}

public struct ThemeDot: Identifiable {
    public let id: Int
    public var position: CGPoint
    public var rgb: (r: Double, g: Double, b: Double)
    public var isPrimary: Bool = false
    public var type: DotType = .standard

    public var color: Color {
        Color(red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255)
    }
}

public enum SpaceColorScheme: String, CaseIterable, Identifiable {
    case auto, light, dark
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }
}

public struct PresetSwatch: Identifiable {
    public let id = UUID()
    public let baseRGB: (r: Double, g: Double, b: Double)
    public let lightness: Double

    public var color: Color {
        Color(red: baseRGB.r / 255, green: baseRGB.g / 255, blue: baseRGB.b / 255)
    }

    public static let defaultPages: [[PresetSwatch]] = {
        let pastel: [(Double, Double, Double)] = [
            (244, 239, 223), (240, 184, 205), (233, 195, 227), (218, 118, 130),
            (235, 133, 112), (220, 206, 127), (91, 236, 173), (145, 155, 181),
        ]
        let dark: [(Double, Double, Double)] = [
            (93, 86, 106), (153, 112, 150), (149, 96, 102), (156, 102, 69),
            (81, 123, 108), (87, 110, 117), (131, 109, 95), (68, 116, 100),
        ]
        func page(_ colors: [(Double, Double, Double)], lightness: Double) -> [PresetSwatch] {
            colors.map { PresetSwatch(baseRGB: $0, lightness: lightness) }
        }
        return [
            page(pastel, lightness: 80),
            page(dark, lightness: 35),
        ]
    }()
}

// MARK: - View Model with Geometric Constraints

@MainActor
public final class ThemePickerViewModel: ObservableObject {
    public static let maxDots = 3
    public let canvasSize: CGFloat = 250

    @Published public var dots: [ThemeDot] = []
    @Published public var opacity: Double = 0.55
    @Published public var texture: Double = 0.2 // 0...1 grain intensity
    @Published public var scheme: SpaceColorScheme = .auto
    private var currentLightness: Double = 55
    
    public init() {
        // Initialize with 3 dots following split-complementary constraint (150° and 210°)
        applySplitComplementary(fromPrimaryRGB: (83, 124, 247), lightness: 60)
    }

    public var primaryColorHex: String {
        guard let first = dots.first else { return "#537CF7" }
        let r = Int(first.rgb.r)
        let g = Int(first.rgb.g)
        let b = Int(first.rgb.b)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    public var primaryColor: Color {
        Color(hex: primaryColorHex)
    }

    public var gradientColorsHex: [String] {
        dots.map { dot in
            let r = Int(dot.rgb.r)
            let g = Int(dot.rgb.g)
            let b = Int(dot.rgb.b)
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }

    public var previewGradient: LinearGradient {
        if dots.count >= 2 {
            let colors = dots.map { $0.color }
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if let first = dots.first {
            let col = first.color
            return LinearGradient(colors: [col, col.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color(hex: "#537CF7"), Color(hex: "#3B82F6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    public func color(at point: CGPoint, type: DotType) -> (r: Double, g: Double, b: Double) {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let radius = canvasSize / 2
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        let normalizedDistance = 1 - min(distance / radius, 1)

        var saturation: Double
        var lightness = currentLightness

        switch type {
        case .explicitBlackWhite:
            saturation = 0
            lightness = (1 - normalizedDistance) * 100
        case .explicitLightness:
            saturation = max(20, min(100, (1 - normalizedDistance) * 100))
        case .standard:
            saturation = 80 + (1 - normalizedDistance) * 20
            currentLightness = max(25, min(85, (1 - normalizedDistance) * 100))
            lightness = currentLightness
        }

        let rgb = ColorMath.hslToRgb(h: angle / 360, s: saturation / 100, l: lightness / 100)
        return (
            min(255, max(0, rgb.r)),
            min(255, max(0, rgb.g)),
            min(255, max(0, rgb.b))
        )
    }

    public func initialPosition(for rgb: (r: Double, g: Double, b: Double)) -> CGPoint {
        let center = canvasSize / 2
        let radius = canvasSize / 2 - 4
        let hsl = ColorMath.rgbToHsl(r: rgb.r, g: rgb.g, b: rgb.b)
        let angle = (hsl.h / 360) * 2 * .pi
        let r = radius * max(0.25, min(0.9, hsl.s))
        let x = center + r * cos(angle)
        let y = center + r * sin(angle)
        return CGPoint(x: x, y: y)
    }

    public func clamp(_ point: CGPoint) -> CGPoint {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let maxRadius = canvasSize / 2 - 4
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist > maxRadius && dist > 0 {
            let scale = maxRadius / dist
            return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
        }
        return point
    }

    // MARK: - Geometric Constraints Enforcement

    /// 1 Dot: free on the wheel.
    /// 2 Dots: necessarily symmetric with respect to center (180°).
    /// 3 Dots: major dot is opposed through center to two secondary dots at 150° and 210° (split-complementary).
    public func addDot(at tapPoint: CGPoint? = nil) {
        guard dots.count < Self.maxDots else { return }
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        
        if dots.isEmpty {
            // Case 1: First dot (free)
            let p = clamp(tapPoint ?? CGPoint(x: center.x + 50, y: center.y))
            let rgb = color(at: p, type: .standard)
            dots = [ThemeDot(id: 0, position: p, rgb: rgb, isPrimary: true)]
        } else if dots.count == 1 {
            // Case 2: Transition from 1 to 2 dots (necessarily symmetric to center: 180°)
            let primary = dots[0]
            let p1 = clamp(CGPoint(x: 2 * center.x - primary.position.x, y: 2 * center.y - primary.position.y))
            let rgb1 = color(at: p1, type: .standard)
            dots = [
                ThemeDot(id: 0, position: primary.position, rgb: primary.rgb, isPrimary: true),
                ThemeDot(id: 1, position: p1, rgb: rgb1, isPrimary: false)
            ]
        } else if dots.count == 2 {
            // Case 3: Transition from 2 to 3 dots (split-complementary: 150° and 210°)
            applySplitComplementary(fromPrimaryPosition: dots[0].position)
        }
        Haptics.selection()
    }

    /// Removes the last dot, but enforces at least 1 dot at all times.
    public func removeLastDot() {
        guard dots.count > 1 else { return } // Prevent removing down to zero
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        
        if dots.count == 3 {
            // From 3 to 2 dots: maintain central symmetry on primary dot
            let primary = dots[0]
            let p1 = clamp(CGPoint(x: 2 * center.x - primary.position.x, y: 2 * center.y - primary.position.y))
            let rgb1 = color(at: p1, type: .standard)
            dots = [
                ThemeDot(id: 0, position: primary.position, rgb: primary.rgb, isPrimary: true),
                ThemeDot(id: 1, position: p1, rgb: rgb1, isPrimary: false)
            ]
        } else if dots.count == 2 {
            // From 2 to 1 dot: primary dot remains, free
            let primary = dots[0]
            dots = [ThemeDot(id: 0, position: primary.position, rgb: primary.rgb, isPrimary: true)]
        }
        Haptics.light()
    }

    public func moveDot(id: Int, to point: CGPoint) {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let clamped = clamp(point)
        
        if dots.count == 1 {
            // 1 Dot: free on spectrum
            dots[0].position = clamped
            dots[0].rgb = color(at: clamped, type: dots[0].type)
        } else if dots.count == 2 {
            // 2 Dots: necessarily symmetric with respect to center (180°)
            if id == 0 {
                dots[0].position = clamped
                dots[0].rgb = color(at: clamped, type: dots[0].type)
                
                let p1 = clamp(CGPoint(x: 2 * center.x - clamped.x, y: 2 * center.y - clamped.y))
                dots[1].position = p1
                dots[1].rgb = color(at: p1, type: dots[1].type)
            } else {
                dots[1].position = clamped
                dots[1].rgb = color(at: clamped, type: dots[1].type)
                
                let p0 = clamp(CGPoint(x: 2 * center.x - clamped.x, y: 2 * center.y - clamped.y))
                dots[0].position = p0
                dots[0].rgb = color(at: p0, type: dots[0].type)
            }
        } else if dots.count == 3 {
            // 3 Dots: major dot (0) has opposite split by center at 150° and 210°
            let dx = clamped.x - center.x
            let dy = clamped.y - center.y
            let radius = min(sqrt(dx * dx + dy * dy), canvasSize / 2 - 4)
            var currentAngle = atan2(dy, dx)
            if currentAngle < 0 { currentAngle += 2 * .pi }
            
            var primaryAngle: Double
            if id == 0 {
                primaryAngle = currentAngle
            } else if id == 1 {
                // Dot 1 is at primaryAngle + 150°
                primaryAngle = currentAngle - (150.0 * .pi / 180.0)
            } else {
                // Dot 2 is at primaryAngle + 210°
                primaryAngle = currentAngle - (210.0 * .pi / 180.0)
            }
            
            updateThreeDots(primaryAngle: primaryAngle, radius: radius)
        }
    }

    private func updateThreeDots(primaryAngle: Double, radius: Double) {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        
        let a0 = primaryAngle
        let a1 = primaryAngle + (150.0 * .pi / 180.0)
        let a2 = primaryAngle + (210.0 * .pi / 180.0)
        
        let p0 = clamp(CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0)))
        let p1 = clamp(CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1)))
        let p2 = clamp(CGPoint(x: center.x + radius * cos(a2), y: center.y + radius * sin(a2)))
        
        let rgb0 = color(at: p0, type: .standard)
        let rgb1 = color(at: p1, type: .standard)
        let rgb2 = color(at: p2, type: .standard)
        
        dots = [
            ThemeDot(id: 0, position: p0, rgb: rgb0, isPrimary: true),
            ThemeDot(id: 1, position: p1, rgb: rgb1, isPrimary: false),
            ThemeDot(id: 2, position: p2, rgb: rgb2, isPrimary: false)
        ]
    }

    public func applySplitComplementary(fromPrimaryPosition pos: CGPoint) {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let dx = pos.x - center.x
        let dy = pos.y - center.y
        let radius = max(25, min(sqrt(dx * dx + dy * dy), canvasSize / 2 - 4))
        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2 * .pi }
        
        updateThreeDots(primaryAngle: angle, radius: radius)
    }

    public func applySplitComplementary(fromPrimaryRGB rgb: (r: Double, g: Double, b: Double), lightness: Double) {
        currentLightness = lightness
        let p0 = initialPosition(for: rgb)
        applySplitComplementary(fromPrimaryPosition: p0)
    }

    /// Applies a preset swatch directly preserving the exact base RGB (including light/pastel tones like cream white)
    public func applyPresetSwatch(_ swatch: PresetSwatch) {
        currentLightness = swatch.lightness
        let baseRGB = swatch.baseRGB
        let baseHsl = ColorMath.rgbToHsl(r: baseRGB.r, g: baseRGB.g, b: baseRGB.b)
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let radius = canvasSize / 2 - 4
        
        let angle0 = (baseHsl.h / 360) * 2 * .pi
        let r = radius * max(0.25, min(0.85, baseHsl.s))
        let p0 = clamp(CGPoint(x: center.x + r * cos(angle0), y: center.y + r * sin(angle0)))
        
        if dots.count <= 1 {
            dots = [
                ThemeDot(id: 0, position: p0, rgb: baseRGB, isPrimary: true, type: .explicitLightness)
            ]
        } else if dots.count == 2 {
            let p1 = clamp(CGPoint(x: 2 * center.x - p0.x, y: 2 * center.y - p0.y))
            let hue1 = (baseHsl.h + 180).truncatingRemainder(dividingBy: 360) / 360
            let rgb1 = ColorMath.hslToRgb(h: hue1, s: baseHsl.s, l: swatch.lightness / 100)
            dots = [
                ThemeDot(id: 0, position: p0, rgb: baseRGB, isPrimary: true, type: .explicitLightness),
                ThemeDot(id: 1, position: p1, rgb: rgb1, isPrimary: false, type: .explicitLightness)
            ]
        } else {
            // 3 dots: split-complementary preserving exact base RGB and harmonious secondary tones
            let a1 = angle0 + (150.0 * .pi / 180.0)
            let a2 = angle0 + (210.0 * .pi / 180.0)
            
            let p1 = clamp(CGPoint(x: center.x + r * cos(a1), y: center.y + r * sin(a1)))
            let p2 = clamp(CGPoint(x: center.x + r * cos(a2), y: center.y + r * sin(a2)))
            
            let hue1 = (baseHsl.h + 150).truncatingRemainder(dividingBy: 360) / 360
            let hue2 = (baseHsl.h + 210).truncatingRemainder(dividingBy: 360) / 360
            
            let rgb1 = ColorMath.hslToRgb(h: hue1, s: baseHsl.s, l: swatch.lightness / 100)
            let rgb2 = ColorMath.hslToRgb(h: hue2, s: baseHsl.s, l: swatch.lightness / 100)
            
            dots = [
                ThemeDot(id: 0, position: p0, rgb: baseRGB, isPrimary: true, type: .explicitLightness),
                ThemeDot(id: 1, position: p1, rgb: rgb1, isPrimary: false, type: .explicitLightness),
                ThemeDot(id: 2, position: p2, rgb: rgb2, isPrimary: false, type: .explicitLightness)
            ]
        }
        Haptics.selection()
    }

    public func loadFromSpace(_ space: Space) {
        self.opacity = space.gradientOpacity
        self.texture = space.gradientTexture
        if let s = SpaceColorScheme(rawValue: space.gradientScheme) {
            self.scheme = s
        }
        
        let hexColors = space.gradientColorsHex
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let radius = canvasSize / 2 - 8
        
        var newDots: [ThemeDot] = []
        for (i, hex) in hexColors.prefix(ThemePickerViewModel.maxDots).enumerated() {
            let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: cleanHex).scanHexInt64(&int)
            let r = Double((int >> 16) & 0xFF)
            let g = Double((int >> 8) & 0xFF)
            let b = Double(int & 0xFF)
            
            let hsl = ColorMath.rgbToHsl(r: r, g: g, b: b)
            let angle = (hsl.h / 360) * 2 * .pi
            let dist = radius * max(0.3, min(0.9, hsl.s))
            let pos = clamp(CGPoint(x: center.x + dist * cos(angle), y: center.y + dist * sin(angle)))
            
            newDots.append(ThemeDot(
                id: i,
                position: pos,
                rgb: (r, g, b),
                isPrimary: i == 0,
                type: .explicitLightness
            ))
        }
        if !newDots.isEmpty {
            self.dots = newDots
        }
    }

    public func cycleDotCount() {
        if dots.count == 1 {
            addDot()
        } else if dots.count == 2 {
            addDot()
        } else {
            removeLastDot()
            removeLastDot()
        }
    }
}

// MARK: - SpaceThemePickerView

public struct SpaceThemePickerView: View {
    @ObservedObject public var model: ThemePickerViewModel
    @State private var presetPage = 0

    public init(model: ThemePickerViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            
            HStack {
                Spacer()
                gradientCanvas
                Spacer()
            }
            
            presetPager
            
            opacitySection
            
            textureDial
        }
        .padding(.vertical, 8)
    }

    // Scheme switch + add / remove / cycle-algorithm buttons
    private var header: some View {
        HStack {
            Picker(selection: $model.scheme, label: EmptyView()) {
                ForEach(SpaceColorScheme.allCases) { scheme in
                    Text(scheme.label).tag(scheme)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    model.addDot()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .disabled(model.dots.count >= ThemePickerViewModel.maxDots)
                .opacity(model.dots.count >= ThemePickerViewModel.maxDots ? 0.35 : 1.0)
                
                Button {
                    model.removeLastDot()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(model.dots.count <= 1)
                .opacity(model.dots.count <= 1 ? 0.35 : 1.0)
                
                Button {
                    model.cycleDotCount()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 19))
            .foregroundColor(.primary)
        }
    }

    // Circular color wheel canvas with geometric constraints visualization
    private var gradientCanvas: some View {
        let center = CGPoint(x: model.canvasSize / 2, y: model.canvasSize / 2)
        
        return ZStack {
            Circle()
                .fill(Color(white: 0.12))
                .overlay(gradientPreview.clipShape(Circle()))
                .frame(width: model.canvasSize, height: model.canvasSize)

            // Geometry Guidelines Layer
            if model.dots.count == 2 {
                // Central Symmetry Axis line
                Path { path in
                    path.move(to: model.dots[0].position)
                    path.addLine(to: model.dots[1].position)
                }
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                
                // Center point indicator
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .position(center)
            } else if model.dots.count == 3 {
                // Split-complementary guidelines
                Path { path in
                    // Line from primary to center
                    path.move(to: model.dots[0].position)
                    path.addLine(to: center)
                    // Lines from center to the two split-complementary dots
                    path.addLine(to: model.dots[1].position)
                    path.move(to: center)
                    path.addLine(to: model.dots[2].position)
                }
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                
                // Center point indicator
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .position(center)
            }

            // Interactive Dots
            ForEach(model.dots) { dot in
                Circle()
                    .fill(dot.color)
                    .frame(width: dot.isPrimary ? 28 : 22, height: dot.isPrimary ? 28 : 22)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: dot.isPrimary ? 3 : 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: dot.isPrimary ? 5 : 2, x: 0, y: 1)
                    .position(dot.position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                model.moveDot(id: dot.id, to: value.location)
                            }
                    )
            }
        }
        .frame(width: model.canvasSize, height: model.canvasSize)
        .contentShape(Circle())
        .gesture(
            SpatialTapGesture().onEnded { value in
                model.addDot(at: value.location)
            }
        )
    }

    private var gradientPreview: some View {
        ZStack {
            ForEach(model.dots) { dot in
                RadialGradient(
                    colors: [dot.color.opacity(model.opacity), .clear],
                    center: UnitPoint(
                        x: dot.position.x / model.canvasSize,
                        y: dot.position.y / model.canvasSize
                    ),
                    startRadius: 0,
                    endRadius: model.canvasSize * 0.75
                )
            }
        }
    }

    private var presetPager: some View {
        HStack(spacing: 8) {
            Button { presetPage = max(presetPage - 1, 0) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(presetPage == 0 ? .secondary.opacity(0.4) : .primary)
            }
            .disabled(presetPage == 0)

            TabView(selection: $presetPage) {
                ForEach(PresetSwatch.defaultPages.indices, id: \.self) { page in
                    HStack(spacing: 10) {
                        ForEach(PresetSwatch.defaultPages[page]) { swatch in
                            Button {
                                model.applyPresetSwatch(swatch)
                            } label: {
                                Circle()
                                    .fill(swatch.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                    .shadow(color: swatch.color.opacity(0.35), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 42)

            Button {
                presetPage = min(presetPage + 1, PresetSwatch.defaultPages.count - 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(presetPage == PresetSwatch.defaultPages.count - 1 ? .secondary.opacity(0.4) : .primary)
            }
            .disabled(presetPage == PresetSwatch.defaultPages.count - 1)
        }
        .buttonStyle(.plain)
    }

    private var opacitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("opacity")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(model.opacity, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            WaveShape(progress: model.opacity)
                .stroke(ZenThemeManager.shared.accentColor, lineWidth: 2.5)
                .frame(height: 22)
            
            Slider(value: $model.opacity, in: 0.25...0.8)
                .tint(ZenThemeManager.shared.accentColor)
        }
    }

    /// Grain dial with 16 discrete notched steps of increasing length, clean empty center
    private var textureDial: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("grain")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let center = CGPoint(x: width / 2, y: height / 2)
                let outerRadius = min(width, height) / 2 - 12
                let totalTicks = 16
                let startAngle = 135.0 * .pi / 180.0
                let sweep = 270.0 * .pi / 180.0
                
                ZStack {
                    // Notches of increasing length from min (4pt) to max (16pt) with 16 discrete steps
                    ForEach(0..<totalTicks, id: \.self) { i in
                        let fraction = Double(i) / Double(totalTicks - 1)
                        let angle = startAngle + fraction * sweep
                        
                        let tickLength: CGFloat = 4.0 + CGFloat(fraction) * 12.0
                        let isHighlighted = fraction <= (model.texture + 0.01)
                        
                        let outerPoint = CGPoint(
                            x: center.x + cos(angle) * outerRadius,
                            y: center.y + sin(angle) * outerRadius
                        )
                        let innerPoint = CGPoint(
                            x: center.x + cos(angle) * (outerRadius - tickLength),
                            y: center.y + sin(angle) * (outerRadius - tickLength)
                        )
                        
                        Path { path in
                            path.move(to: innerPoint)
                            path.addLine(to: outerPoint)
                        }
                        .stroke(
                            isHighlighted ? ZenThemeManager.shared.accentColor : Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: isHighlighted ? 2.5 : 1.5, lineCap: .round)
                        )
                    }
                    
                    // Draggable Dial Handle snapped to the 16 notched steps
                    let handleAngle = startAngle + model.texture * sweep
                    let handleRadius = outerRadius + 3
                    
                    Circle()
                        .fill(ZenThemeManager.shared.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .shadow(color: ZenThemeManager.shared.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                        .position(
                            x: center.x + cos(handleAngle) * handleRadius,
                            y: center.y + sin(handleAngle) * handleRadius
                        )
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var angle = atan2(dy, dx)
                        if angle < 0 { angle += 2 * .pi }
                        
                        var relAngle = angle - startAngle
                        if relAngle < 0 { relAngle += 2 * .pi }
                        
                        let rawFraction: Double
                        if relAngle <= sweep {
                            rawFraction = min(max(relAngle / sweep, 0), 1)
                        } else {
                            let distToStart = 2 * .pi - relAngle
                            let distToEnd = relAngle - sweep
                            rawFraction = (distToStart < distToEnd) ? 0 : 1
                        }
                        
                        let step = Int(round(rawFraction * Double(totalTicks - 1)))
                        let newTexture = Double(step) / Double(totalTicks - 1)
                        if abs(newTexture - model.texture) > 0.001 {
                            model.texture = newTexture
                            Haptics.selection()
                        }
                    }
                )
            }
            .frame(height: 120)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(16)
    }
}

// MARK: - SpaceThemePickerDetailView

public struct SpaceThemePickerDetailView: View {
    @ObservedObject public var model: ThemePickerViewModel
    
    public init(model: ThemePickerViewModel) {
        self.model = model
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            SpaceThemePickerView(model: model)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .navigationTitle(String(localized: "gradient_and_theme", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WaveShape

public struct WaveShape: Shape {
    public var progress: Double // range ~0.25...0.8

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let normalized = min(max((progress - 0.25) / (0.8 - 0.25), 0), 1)
        let amplitude = normalized * (rect.height / 2 - 2)
        let midY = rect.midY
        let waveLength = rect.width / 3

        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        let steps = 60
        for i in 0...steps {
            let x = rect.width * Double(i) / Double(steps)
            let y = midY - sin((x / waveLength) * .pi) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

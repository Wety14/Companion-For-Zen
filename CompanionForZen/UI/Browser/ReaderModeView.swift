import SwiftUI

/// Distraction-free clean reader view for articles.
public struct ReaderModeView: View {
    @ObservedObject var readerService = ReaderModeService.shared
    @State private var selectedTheme: ReaderTheme = .sepia
    @State private var selectedFont: ReaderFont = .serif
    @State private var fontSize: CGFloat = 19.0
    
    public var body: some View {
        ZStack {
            currentBackgroundColor
                .ignoresSafeArea()
            
            if let article = readerService.currentArticle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Top Reader Bar
                        HStack {
                            Button(action: {
                                Haptics.light()
                                readerService.exitReader()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                    Text("exit_reader_mode")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(currentAccentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentTextColor.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            // Reader Controls Menu
                            Menu {
                                Section(String(localized: "theme_section", bundle: .main)) {
                                    ForEach(ReaderTheme.allCases) { theme in
                                        Button(theme.rawValue) {
                                            selectedTheme = theme
                                        }
                                    }
                                }
                                Section(String(localized: "font", bundle: .main)) {
                                    ForEach(ReaderFont.allCases) { font in
                                        Button(font.rawValue) {
                                            selectedFont = font
                                        }
                                    }
                                }
                                Section(String(localized: "text_size", bundle: .main)) {
                                    Button(String(localized: "increase_text_size", bundle: .main)) {
                                        fontSize = min(28, fontSize + 2)
                                    }
                                    Button(String(localized: "decrease_text_size", bundle: .main)) {
                                        fontSize = max(14, fontSize - 2)
                                    }
                                }
                            } label: {
                                Image(systemName: "textformat.size")
                                    .font(.title3)
                                    .foregroundColor(currentTextColor)
                                    .frame(width: 38, height: 38)
                                    .background(currentTextColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.bottom, 10)
                        
                        // Article Title
                        Text(article.title)
                            .font(titleFont)
                            .foregroundColor(currentTextColor)
                            .lineSpacing(4)
                        
                        // Author / Byline
                        if let byline = article.byline, !byline.isEmpty {
                            Text(byline)
                                .font(.subheadline)
                                .foregroundColor(currentTextColor.opacity(0.7))
                        }
                        
                        Divider()
                            .background(currentTextColor.opacity(0.2))
                        
                        // Article Body
                        Text(article.plainText)
                            .font(bodyFont)
                            .foregroundColor(currentTextColor)
                            .lineSpacing(8)
                    }
                    .padding(24)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("extracting_content")
                        .font(.subheadline)
                        .foregroundColor(currentTextColor.opacity(0.7))
                }
            }
        }
    }
    
    private var currentBackgroundColor: Color {
        switch selectedTheme {
        case .sepia: return Color(hex: "#FBF0D9")
        case .dark: return Color(hex: "#18181B")
        case .oled: return Color(hex: "#000000")
        case .cream: return Color(hex: "#F2F0E3")
        }
    }
    
    private var currentTextColor: Color {
        switch selectedTheme {
        case .sepia: return Color(hex: "#433422")
        case .dark: return Color(hex: "#E4E4E7")
        case .oled: return Color(hex: "#FFFFFF")
        case .cream: return Color(hex: "#27272A")
        }
    }
    
    private var currentAccentColor: Color {
        ZenThemeManager.shared.accentColor
    }
    
    private var titleFont: Font {
        switch selectedFont {
        case .system: return .system(size: fontSize + 8, weight: .bold, design: .default)
        case .serif: return .system(size: fontSize + 8, weight: .bold, design: .serif)
        case .monospace: return .system(size: fontSize + 6, weight: .bold, design: .monospaced)
        }
    }
    
    private var bodyFont: Font {
        switch selectedFont {
        case .system: return .system(size: fontSize, weight: .regular, design: .default)
        case .serif: return .system(size: fontSize, weight: .regular, design: .serif)
        case .monospace: return .system(size: fontSize - 1, weight: .regular, design: .monospaced)
        }
    }
}

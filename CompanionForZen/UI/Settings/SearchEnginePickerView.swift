import SwiftUI

/// Search Engine picker view supporting DuckDuckGo, Brave, Google, Ecosia, Kagi, Qwant, SearXNG, and Custom URL.
/// Uses official brand logos/favicons directly from each search engine.
public struct SearchEnginePickerView: View {
    @Binding var searchConfig: SearchEngineConfig
    @ObservedObject var themeManager = ZenThemeManager.shared
    @ObservedObject var locManager = LocalizationManager.shared
    
    public var body: some View {
        List {
            Section(String(localized: "builtin_engines", bundle: .main)) {
                ForEach(SearchEngineType.allCases.filter { $0 != .custom }) { engine in
                    Button(action: {
                        Haptics.selection()
                        searchConfig.selectedType = engine
                    }) {
                        HStack(spacing: 14) {
                            SearchEngineLogoView(engine: engine)
                            
                            Text(engine.localizedName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if searchConfig.selectedType == engine {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section(String(localized: "custom_engine", bundle: .main)) {
                Button(action: {
                    Haptics.selection()
                    searchConfig.selectedType = .custom
                }) {
                    HStack(spacing: 14) {
                        SearchEngineLogoView(engine: .custom)
                        
                        Text(SearchEngineType.custom.localizedName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if searchConfig.selectedType == .custom {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                if searchConfig.selectedType == .custom {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "custom_engine_template", bundle: .main))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("https://example.com/search?q=%@", text: $searchConfig.customURLTemplate)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 14, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "search_engine", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Renders the official proprietary brand favicon / icon for each search engine.
public struct SearchEngineLogoView: View {
    public let engine: SearchEngineType
    public var size: CGFloat
    
    public init(engine: SearchEngineType, size: CGFloat = 24) {
        self.engine = engine
        self.size = size
    }
    
    public var body: some View {
        Group {
            if let url = engine.iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
                    default:
                        brandFallback
                    }
                }
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: size * 0.7, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: max(size, 24), height: max(size, 24))
    }
    
    @ViewBuilder
    private var brandFallback: some View {
        switch engine {
        case .google:
            ZStack {
                Circle().fill(Color.white)
                Text("G")
                    .font(.system(size: size * 0.65, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.12), radius: 1)
        case .duckDuckGo:
            ZStack {
                Circle().fill(Color(red: 0.87, green: 0.35, blue: 0.14))
                Image(systemName: "bird.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .brave:
            ZStack {
                Circle().fill(Color(red: 0.98, green: 0.33, blue: 0.11))
                Image(systemName: "shield.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .ecosia:
            ZStack {
                Circle().fill(Color(red: 0.12, green: 0.60, blue: 0.36))
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .kagi:
            ZStack {
                Circle().fill(Color(red: 0.97, green: 0.72, blue: 0.20))
                Image(systemName: "dog.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.black)
            }
            .frame(width: size, height: size)
        case .qwant:
            ZStack {
                Circle().fill(Color(red: 0.35, green: 0.40, blue: 0.95))
                Text("Q")
                    .font(.system(size: size * 0.6, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .searxng:
            ZStack {
                Circle().fill(Color(red: 0.20, green: 0.60, blue: 0.86))
                Image(systemName: "server.rack")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .custom:
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: size * 0.7))
                .foregroundColor(.secondary)
        }
    }
}

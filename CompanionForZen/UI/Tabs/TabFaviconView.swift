import SwiftUI

/// Renders the real favicon of a tab using resolved favicon URLs with an async image loader and fallback.
public struct TabFaviconView: View {
    public let tab: Tab
    public var size: CGFloat = 20
    public var fallbackColor: Color = .white
    
    public init(tab: Tab, size: CGFloat = 20, fallbackColor: Color = .white) {
        self.tab = tab
        self.size = size
        self.fallbackColor = fallbackColor
    }
    
    public var body: some View {
        Group {
            if isZenTab {
                ZenLogoView(
                    size: size,
                    showBackground: false,
                    ringColor: fallbackColor
                )
            } else if let iconURL = tab.resolvedFaviconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous))
                    case .failure, .empty:
                        fallbackView
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
    }
    
    private var isZenTab: Bool {
        tab.url.host?.contains("zen-browser") == true || tab.title.lowercased().contains("zen browser")
    }
    
    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(fallbackColor.opacity(0.18))
                .frame(width: size, height: size)
            
            Text(String(tab.displayHost.prefix(1)).uppercased())
                .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
                .foregroundColor(fallbackColor)
        }
    }
}

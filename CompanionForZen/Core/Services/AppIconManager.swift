import UIKit
import SwiftUI

@MainActor
public final class AppIconManager: ObservableObject {
    public static let shared = AppIconManager()

    public enum AppIcon: String, Codable, CaseIterable, Identifiable, Sendable {
        case coral = "CoralIcon"        // nil en interne pour setAlternateIconName (icône par défaut)
        case dark = "DarkIcon"
        case retro = "RetroIcon"
        case twilight = "TwilightIcon"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .coral: return "Zen Coral"
            case .dark: return "Zen Dark"
            case .retro: return "Zen Retro"
            case .twilight: return "Zen Twilight"
            }
        }

        public var subtitle: String {
            switch self {
            case .coral: return "Teinte corail officielle"
            case .dark: return "Noir profond épuré"
            case .retro: return "Violet néon & or rétro"
            case .twilight: return "Bleu classique océanique"
            }
        }

        public var iconColor: Color {
            switch self {
            case .coral: return Color(hex: "#F76F53")
            case .dark: return Color(hex: "#18181B")
            case .retro: return Color(hex: "#7A3DE3")
            case .twilight: return Color(hex: "#5C7BEF")
            }
        }

        public var ringColor: Color {
            switch self {
            case .retro: return Color(hex: "#F5C144")
            default: return .white
            }
        }

        // Nom à passer à l'API : nil pour l'icône principale (CoralIcon)
        public var alternateIconName: String? {
            iconName
        }

        public var iconName: String? {
            self == .coral ? nil : rawValue
        }

        // Nom de l'image "aperçu" à afficher dans le sélecteur
        public var previewImageName: String {
            "Preview-\(rawValue)"
        }
    }

    @Published public private(set) var currentIcon: AppIcon

    public init() {
        let name = UIApplication.shared.alternateIconName
        currentIcon = AppIcon.allCases.first { $0.iconName == name } ?? .coral
    }

    public var isSupported: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    public func setIcon(_ icon: AppIcon) {
        guard isSupported, icon != currentIcon else { return }

        UIApplication.shared.setAlternateIconName(icon.iconName) { [weak self] error in
            Task { @MainActor in
                if let error {
                    print("Erreur changement d'icône : \(error.localizedDescription)")
                } else {
                    self?.currentIcon = icon
                }
            }
        }
    }
}

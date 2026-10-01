import Foundation
import Combine
import SwiftUI

/// Available languages supported by Companion for Zen.
public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case ar, bg, cs, da, de, el, en, enGB = "en-GB", es, fa, fi, fr, he, hu, `is`, it, nb, nl, nn, pl
    case ptBR = "pt-BR"
    case ptPT = "pt-PT"
    case ro, ru, sk, sv, tr, uk

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ar: return "العربية"
        case .bg: return "Български"
        case .cs: return "Čeština"
        case .da: return "Dansk"
        case .de: return "Deutsch"
        case .el: return "Ελληνικά"
        case .en: return "English"
        case .enGB: return "English (UK)"
        case .es: return "Español"
        case .fa: return "فارسی"
        case .fi: return "Suomi"
        case .fr: return "Français"
        case .he: return "עברית"
        case .hu: return "Magyar"
        case .is: return "Íslenska"
        case .it: return "Italiano"
        case .nb: return "Norsk bokmål"
        case .nl: return "Nederlands"
        case .nn: return "Norsk nynorsk"
        case .pl: return "Polski"
        case .ptBR: return "Português (Brasil)"
        case .ptPT: return "Português (Portugal)"
        case .ro: return "Română"
        case .ru: return "Русский"
        case .sk: return "Slovenčina"
        case .sv: return "Svenska"
        case .tr: return "Türkçe"
        case .uk: return "Українська"
        }
    }

    public static func preferred(for locale: Locale = .current) -> AppLanguage {
        // Priorité aux langues préférées du système (iOS Settings)
        for lang in Locale.preferredLanguages {
            let normalized = lang.replacingOccurrences(of: "_", with: "-")
            if let match = AppLanguage(rawValue: normalized) {
                return match
            }
            let baseCode = normalized.split(separator: "-").first.map(String.init) ?? normalized
            if let match = AppLanguage(rawValue: baseCode) {
                return match
            }
        }
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let exactMatch = AppLanguage(rawValue: identifier) {
            return exactMatch
        }
        if let languageCode = locale.language.languageCode?.identifier,
           let languageMatch = allCases.first(where: { $0.rawValue == languageCode }) {
            return languageMatch
        }
        // Par défaut Anglais si la langue du système est indisponible
        return .en
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// Localization Manager backed by Apple String Catalog (Localizable.xcstrings).
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            TabManager.safeDefaults.set(currentLanguage.rawValue, forKey: "app_language")
            objectWillChange.send()
        }
    }

    public var locale: Locale {
        currentLanguage.locale
    }

    /// Bundle that points to the selected language's .lproj in real-time without requiring an app restart.
    public var localizedBundle: Bundle {
        let code = currentLanguage.rawValue
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        let baseCode = code.split(separator: "-").first.map(String.init) ?? code
        if let path = Bundle.main.path(forResource: baseCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            let initial = AppLanguage.preferred(for: .current)
            self.currentLanguage = initial
            UserDefaults.standard.set(initial.rawValue, forKey: "app_language")
            UserDefaults.standard.set([initial.rawValue], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            TabManager.safeDefaults.set(initial.rawValue, forKey: "app_language")
        }
    }

    public func setLanguage(_ newLanguage: AppLanguage) {
        guard currentLanguage != newLanguage else { return }
        currentLanguage = newLanguage
    }

    /// Returns the localized string for the specified key from Localizable.xcstrings.
    /// Uses `String(localized:table:bundle:locale:)` which reads the .xcstrings
    /// catalog directly — no separate .lproj directories required.
    public func string(for key: String) -> String {
        let result = localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if (result.isEmpty || result == key) && currentLanguage != .en {
            if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let enBundle = Bundle(path: enPath) {
                let enResult = enBundle.localizedString(forKey: key, value: nil, table: "Localizable")
                if !enResult.isEmpty && enResult != key {
                    return enResult
                }
            }
        }
        return result
    }
}


extension String {
    /// Overload that automatically uses the app's currently selected language bundle from `LocalizationManager`.
    public init(localized key: String.LocalizationValue, bundle: Bundle? = nil) {
        let activeBundle: Bundle
        if bundle == nil || bundle == .main {
            activeBundle = LocalizationManager.shared.localizedBundle
        } else {
            activeBundle = bundle!
        }
        let result = String(localized: key, table: "Localizable", bundle: activeBundle)
        self = result
    }
}

import Foundation
import WebKit
import SwiftUI
import Security
#if canImport(Translation)
import Translation
#endif

/// Translation providers available in Zen Browser.
public enum TranslationProvider: String, CaseIterable, Identifiable {
    case none = "none"
    case askPerTab = "ask_per_tab"
    case system = "system"
    case google = "google"
    
    public var id: String { rawValue }
    
    public var localizedTitle: String {
        switch self {
        case .none:
            return String(localized: "translation_provider_none", bundle: .main)
        case .askPerTab:
            return String(localized: "translation_provider_ask", bundle: .main)
        case .system:
            return String(localized: "translation_provider_system", bundle: .main)
        case .google:
            return String(localized: "translation_provider_google", bundle: .main)
        }
    }
}

/// Service handling in-page and web translation using Apple's native engine or Google Translate.
public final class TranslationService: ObservableObject {
    public static let shared = TranslationService()
    
    @Published public var provider: TranslationProvider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: "translation_provider")
        }
    }
    
    @Published public var isTranslating: Bool = false
    @Published public var isPageTranslated: Bool = false
    public var originalURLBeforeTranslation: URL? = nil
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "translation_provider"),
           let p = TranslationProvider(rawValue: saved) {
            self.provider = p
        } else {
            // Default to system translator or ask per tab
            self.provider = .system
        }
    }
    
    public func reset() {
        self.isPageTranslated = false
        self.isTranslating = false
        self.originalURLBeforeTranslation = nil
    }
    
    // MARK: - Restore Original
    
    public func restoreOriginal(webView: WKWebView) async {
        if let originalURL = originalURLBeforeTranslation {
            await MainActor.run {
                self.originalURLBeforeTranslation = nil
                self.isPageTranslated = false
                let request = URLRequest(url: originalURL)
                webView.load(request)
            }
            return
        }
        
        let restoreScript = """
        (function() {
            if (!window.__zenTextNodes || !window.__zenOriginalTexts) return;
            for (let i = 0; i < window.__zenTextNodes.length && i < window.__zenOriginalTexts.length; i++) {
                window.__zenTextNodes[i].nodeValue = window.__zenOriginalTexts[i];
            }
        })();
        """
        _ = try? await webView.evaluateJavaScript(restoreScript)
        await MainActor.run {
            self.isPageTranslated = false
        }
    }
    
    // MARK: - Google Translate
    
    public func translateWithGoogle(webView: WKWebView, currentURL: URL?) {
        guard let url = currentURL ?? webView.url else { return }
        
        let targetLang = Locale.current.language.languageCode?.identifier ?? "fr"
        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let googleURL = URL(string: "https://translate.google.com/translate?sl=auto&tl=\(targetLang)&u=\(encodedURL)") else {
            return
        }
        
        self.originalURLBeforeTranslation = url
        self.isPageTranslated = true
        let request = URLRequest(url: googleURL)
        webView.load(request)
    }
    

    // MARK: - Apple Native System Translation
    
    #if canImport(Translation)
    @available(iOS 18.0, *)
    public func translateWebPage(using session: TranslationSession, webView: WKWebView) async {
        await MainActor.run {
            self.isTranslating = true
        }
        
        let extractScript = """
        (function() {
            const walker = document.createTreeWalker(
                document.body,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode: function(node) {
                        const parent = node.parentNode;
                        if (!parent) return NodeFilter.FILTER_REJECT;
                        const tag = parent.tagName.toLowerCase();
                        if (['script', 'style', 'noscript', 'code', 'pre'].includes(tag)) {
                            return NodeFilter.FILTER_REJECT;
                        }
                        const text = node.nodeValue.trim();
                        if (text.length > 1 && !/^[\\d\\s\\p{P}]+$/u.test(text)) {
                            return NodeFilter.FILTER_ACCEPT;
                        }
                        return NodeFilter.FILTER_REJECT;
                    }
                }
            );
            
            window.__zenTextNodes = [];
            window.__zenOriginalTexts = [];
            const texts = [];
            let node;
            let count = 0;
            while ((node = walker.nextNode()) && count < 300) {
                window.__zenTextNodes.push(node);
                window.__zenOriginalTexts.push(node.nodeValue);
                texts.push(node.nodeValue);
                count++;
            }
            return texts;
        })();
        """
        
        do {
            let result = try await webView.evaluateJavaScript(extractScript)
            guard let texts = result as? [String], !texts.isEmpty else {
                await MainActor.run { self.isTranslating = false }
                return
            }
            
            var translated: [String] = []
            let chunkSize = 40
            for i in stride(from: 0, to: texts.count, by: chunkSize) {
                let chunkTexts = Array(texts[i..<min(i + chunkSize, texts.count)])
                let chunkRequests = chunkTexts.map { TranslationSession.Request(sourceText: $0) }
                do {
                    for try await response in session.translate(batch: chunkRequests) {
                        translated.append(response.targetText)
                    }
                } catch {
                    // Fallback to original text for this chunk if translation encounters an issue
                    translated.append(contentsOf: chunkTexts)
                }
            }
            
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(translated),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let replaceScript = """
                (function() {
                    const translated = \(jsonString);
                    if (!window.__zenTextNodes) return;
                    for (let i = 0; i < window.__zenTextNodes.length && i < translated.length; i++) {
                        window.__zenTextNodes[i].nodeValue = translated[i];
                    }
                })();
                """
                _ = try? await webView.evaluateJavaScript(replaceScript)
                
                await MainActor.run {
                    self.isPageTranslated = true
                }
            }
        } catch {
            print("Apple Native Translation failed: \(error)")
        }
        
        await MainActor.run {
            self.isTranslating = false
        }
    }
    #endif
}

// MARK: - Apple Keychain Helper

public enum KeychainHelper {
    private static let service = "app.zen-browser.companion.keychain"
    
    public static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public static func save(key: String, string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }
    
    public static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    public static func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

import Foundation
import WebKit
import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// Service handling in-page and web translation using Apple's native translation engine.
public final class TranslationService: ObservableObject {
    public static let shared = TranslationService()
    
    @Published public var isTranslating: Bool = false
    @Published public var isPageTranslated: Bool = false
    @Published public var alwaysAllowTranslation: Bool {
        didSet {
            UserDefaults.standard.set(alwaysAllowTranslation, forKey: "translation_always_allow")
        }
    }
    
    private init() {
        self.alwaysAllowTranslation = UserDefaults.standard.bool(forKey: "translation_always_allow")
    }
    
    public func reset() {
        self.isPageTranslated = false
        self.isTranslating = false
    }
    
    public func restoreOriginal(webView: WKWebView) async {
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

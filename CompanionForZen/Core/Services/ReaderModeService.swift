import Foundation
import WebKit

public struct ReaderArticle: Equatable {
    public let title: String
    public let byline: String?
    public let contentHTML: String
    public let plainText: String
    public let url: URL
}

/// Service that extracts readable article content and renders a clean distraction-free view.
public final class ReaderModeService: ObservableObject {
    public static let shared = ReaderModeService()
    
    @Published public var isReaderActive: Bool = false
    @Published public var currentArticle: ReaderArticle?
    
    private init() {}
    
    /// Script to extract article body, heading, and clean paragraphs
    public static let readerExtractorJS = """
    (function() {
        try {
            // Find article title
            const h1 = document.querySelector('h1');
            const title = h1 ? h1.innerText : (document.title || '');
            
            // Find author or byline
            let byline = '';
            const authorEl = document.querySelector('[rel="author"], .byline, .author, time');
            if (authorEl) {
                byline = authorEl.innerText;
            }
            
            // Find main content container
            const candidates = document.querySelectorAll('article, main, .post-content, .article-body, .entry-content, [role="main"]');
            let contentEl = null;
            if (candidates.length > 0) {
                contentEl = candidates[0];
            } else {
                contentEl = document.body;
            }
            
            // Extract clean paragraphs
            const paragraphs = Array.from(contentEl.querySelectorAll('p, h2, h3, blockquote, ul, ol, img'))
                .filter(el => {
                    const text = el.innerText || '';
                    if (el.tagName === 'IMG') return el.src && el.src.startsWith('http');
                    return text.trim().length > 25;
                })
                .map(el => {
                    if (el.tagName === 'IMG') {
                        return '<img src="' + el.src + '" style="max-width:100%; border-radius:12px; margin: 16px 0;" />';
                    }
                    return '<' + el.tagName.toLowerCase() + '>' + el.innerHTML + '</' + el.tagName.toLowerCase() + '>';
                })
                .join('');
                
            return JSON.stringify({
                title: title,
                byline: byline,
                content: paragraphs.length > 0 ? paragraphs : contentEl.innerHTML
            });
        } catch (e) {
            return JSON.stringify({ title: document.title, byline: '', content: '<p>' + document.body.innerText + '</p>' });
        }
    })();
    """
    
    public func extractArticle(from webView: WKWebView, completion: @escaping (ReaderArticle?) -> Void) {
        guard let url = webView.url else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(Self.readerExtractorJS) { result, error in
            guard let jsonStr = result as? String,
                  let data = jsonStr.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let title = dict["title"],
                  let content = dict["content"] else {
                completion(nil)
                return
            }
            
            let article = ReaderArticle(
                title: title,
                byline: dict["byline"],
                contentHTML: content,
                plainText: content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                url: url
            )
            DispatchQueue.main.async {
                self.currentArticle = article
                self.isReaderActive = true
            }
            completion(article)
        }
    }
    
    public func exitReader() {
        isReaderActive = false
        currentArticle = nil
    }
}

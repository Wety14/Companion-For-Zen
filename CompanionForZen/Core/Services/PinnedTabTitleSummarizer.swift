import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service handling background summarization and shortening of pinned tab titles
/// using Apple Intelligence (FoundationModels) when available on the device.
public final class PinnedTabTitleSummarizer {
    public static let shared = PinnedTabTitleSummarizer()
    
    private init() {}
    
    /// Checks whether Apple Intelligence foundation models are available and ready on this device.
    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }
    
    /// Checks whether automatic AI title shortening is enabled by user preference in Settings.
    public var isAutoRenameEnabled: Bool {
        UserDefaults.standard.object(forKey: "ai_auto_rename_pinned_tabs") as? Bool ?? true
    }
    
    /// Shortens the given tab title in the background if Apple Intelligence is available.
    /// - Parameters:
    ///   - title: The initial title of the webpage or tab.
    ///   - url: The URL of the tab (used to provide website host context).
    /// - Returns: A concise shortened title (e.g. 1-3 words) if available, or the original title.
    public func shortenTitle(title: String, url: URL?) async -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            return url?.host ?? title
        }
        
        guard isAutoRenameEnabled && isAvailable else {
            return cleanTitle
        }
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *) {
            do {
                let instructions = """
                You are a title shortener for browser pinned tabs.
                Given a webpage title and website URL, produce a very concise name (1 to 3 words, maximum 25 characters) that best represents the tab for compact display.
                Keep the brand name, service name, or core topic.
                Do not include quotes, markdown formatting, explanations, or punctuation at the end.
                Respond ONLY with the shortened title.
                """
                
                let session = LanguageModelSession(
                    model: SystemLanguageModel.default,
                    instructions: instructions
                )
                
                var prompt = "Title: \(cleanTitle)"
                if let host = url?.host, !host.isEmpty {
                    prompt += "\nHost: \(host)"
                }
                
                let response = try await session.respond(to: prompt)
                var result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Clean up any surrounding quotes or markdown formatting
                let quoteCharacters = CharacterSet(charactersIn: "\"\'`«»“”")
                result = result.trimmingCharacters(in: quoteCharacters)
                
                // Strip common prefixes if generated
                let prefixesToStrip = ["title:", "shortened title:", "tab title:", "name:"]
                for prefix in prefixesToStrip {
                    if result.lowercased().hasPrefix(prefix) {
                        result = String(result.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                result = result.trimmingCharacters(in: quoteCharacters)
                
                if !result.isEmpty && result.count <= 35 {
                    return result
                }
            } catch {
                print("PinnedTabTitleSummarizer: Error generating short title with Apple Intelligence: \(error)")
            }
        }
        #endif
        
        return cleanTitle
    }
}

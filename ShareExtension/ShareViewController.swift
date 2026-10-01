import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        extractSharedURLAndTitle { [weak self] url, title in
            guard let self = self else { return }
            guard let url = url else {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                return
            }
            
            self.presentShareView(url: url, title: title)
        }
    }
    
    private func cleanTrackingParameters(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return url
        }
        let knownTrackers: Set<String> = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "utm_cid", "utm_reader", "utm_name", "utm_pubreferrer",
            "fbclid", "fbadid", "fb_action_ids", "fb_action_types", "fb_source",
            "igshid", "igsh", "share_id", "ref_src", "ref_url",
            "gclid", "gclsrc", "dclid", "gad_source", "gbraid", "wbraid", "si",
            "msclkid", "_r", "_t", "checksum", "sec_user_id", "tt_medium", "tt_content",
            "mc_eid", "mc_cid", "_hsenc", "_hsmi", "mkt_tok", "ref", "affiliate"
        ]
        let filtered = queryItems.filter { item in
            let name = item.name.lowercased()
            if name.hasPrefix("utm_") { return false }
            if (name == "t" || name == "s") && (components.host?.contains("twitter.com") == true || components.host?.contains("x.com") == true) {
                return false
            }
            return !knownTrackers.contains(name)
        }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url ?? url
    }

    private func presentShareView(url: URL, title: String?) {
        let cleanURL = cleanTrackingParameters(from: url)
        let resolvedTitle = title ?? cleanURL.host ?? "Lien partagé"
        
        let rootView = ShareExtensionView(
            url: cleanURL,
            initialTitle: resolvedTitle,
            onSave: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: NSError(domain: "ZenShare", code: 0, userInfo: nil))
            }
        )
        
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    private func extractSharedURLAndTitle(completion: @escaping (URL?, String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
            completion(nil, nil)
            return
        }
        
        var extractedURL: URL?
        var extractedTitle: String?
        
        let group = DispatchGroup()
        
        for item in items {
            if let itemTitle = item.attributedTitle?.string ?? item.attributedContentText?.string,
               !itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if extractedTitle == nil {
                    extractedTitle = itemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // 1. Check for web URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                        defer { group.leave() }
                        if let url = item as? URL {
                            if extractedURL == nil { extractedURL = url }
                        } else if let urlStr = item as? String, let url = URL(string: urlStr) {
                            if extractedURL == nil { extractedURL = url }
                        }
                    }
                }
                // 2. Check for plain text (e.g. WhatsApp link sharing or message with link)
                else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                        defer { group.leave() }
                        if let text = item as? String, let self = self {
                            if let foundURL = self.detectURL(in: text) {
                                if extractedURL == nil { extractedURL = foundURL }
                            }
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(extractedURL, extractedTitle)
        }
    }
    
    private func detectURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = URL(string: trimmed), directURL.scheme == "http" || directURL.scheme == "https" {
            return directURL
        }
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }.first
    }
}

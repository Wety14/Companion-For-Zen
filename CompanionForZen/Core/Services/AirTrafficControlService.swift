import Foundation
import SwiftUI

/// Matching rule type for routing external links to specific spaces (Zen Air Traffic Control).
public enum AirTrafficMatchType: String, Codable, CaseIterable, Identifiable {
    case contains = "contains"
    case exact = "exact"
    case hostMatches = "hostMatches"
    case startsWith = "startsWith"
    
    public var id: String { rawValue }
    
    public var localizedLabel: String {
        switch self {
        case .contains: return "Contient"
        case .exact: return "Est exactement"
        case .hostMatches: return "Domaine (hôte)"
        case .startsWith: return "Commence par"
        }
    }
}

/// A single routing rule for Air Traffic Control.
public struct AirTrafficRule: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var matchType: AirTrafficMatchType
    public var pattern: String
    public var targetSpaceId: UUID
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        matchType: AirTrafficMatchType = .contains,
        pattern: String = "",
        targetSpaceId: UUID,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.matchType = matchType
        self.pattern = pattern
        self.targetSpaceId = targetSpaceId
        self.isEnabled = isEnabled
    }
    
    public func matches(url: URL) -> Bool {
        guard isEnabled else { return false }
        let cleanPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanPattern.isEmpty else { return false }
        
        let urlString = url.absoluteString.lowercased()
        
        switch matchType {
        case .contains:
            return urlString.contains(cleanPattern)
        case .exact:
            return urlString == cleanPattern || urlString == cleanPattern + "/"
        case .hostMatches:
            let host = (url.host ?? "").lowercased()
            return host == cleanPattern || host.hasSuffix("." + cleanPattern)
        case .startsWith:
            return urlString.hasPrefix(cleanPattern)
        }
    }
}

/// Fallback strategy when no rule matches an incoming URL.
public enum AirTrafficFallbackMode: String, Codable, CaseIterable, Identifiable {
    case mostRecent = "mostRecent"
    case specificSpace = "specificSpace"
    
    public var id: String { rawValue }
    
    public var localizedLabel: String {
        switch self {
        case .mostRecent: return "Dernier espace accédé"
        case .specificSpace: return "Espace prédéfini"
        }
    }
}

/// Air Traffic Control service directing incoming links from other apps to appropriate Zen Spaces.
public final class AirTrafficControlService: ObservableObject {
    public static let shared = AirTrafficControlService()
    
    private let rulesKey = "zen_air_traffic_rules"
    private let fallbackModeKey = "zen_air_traffic_fallback_mode"
    private let fallbackSpaceIdKey = "zen_air_traffic_fallback_space_id"
    
    @Published public var rules: [AirTrafficRule] = []
    @Published public var fallbackMode: AirTrafficFallbackMode = .mostRecent
    @Published public var fallbackSpaceId: UUID? = nil
    
    private var defaults: UserDefaults {
        TabManager.safeDefaults
    }
    
    private init() {
        loadSettings()
    }
    
    public func loadSettings() {
        let storage = defaults
        
        // Load rules
        if let data = storage.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([AirTrafficRule].self, from: data) {
            self.rules = decoded
        } else {
            self.rules = []
        }
        
        // Load fallback mode
        if let rawMode = storage.string(forKey: fallbackModeKey),
           let mode = AirTrafficFallbackMode(rawValue: rawMode) {
            self.fallbackMode = mode
        } else {
            self.fallbackMode = .mostRecent
        }
        
        // Load fallback space
        if let rawSpace = storage.string(forKey: fallbackSpaceIdKey),
           let spaceUUID = UUID(uuidString: rawSpace) {
            self.fallbackSpaceId = spaceUUID
        } else {
            self.fallbackSpaceId = nil
        }
    }
    
    public func saveSettings() {
        let storage = defaults
        
        if let encoded = try? JSONEncoder().encode(rules) {
            storage.set(encoded, forKey: rulesKey)
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
        
        storage.set(fallbackMode.rawValue, forKey: fallbackModeKey)
        UserDefaults.standard.set(fallbackMode.rawValue, forKey: fallbackModeKey)
        
        if let fallbackId = fallbackSpaceId {
            storage.set(fallbackId.uuidString, forKey: fallbackSpaceIdKey)
            UserDefaults.standard.set(fallbackId.uuidString, forKey: fallbackSpaceIdKey)
        } else {
            storage.removeObject(forKey: fallbackSpaceIdKey)
            UserDefaults.standard.removeObject(forKey: fallbackSpaceIdKey)
        }
    }
    
    public func addRule(_ rule: AirTrafficRule) {
        rules.append(rule)
        saveSettings()
    }
    
    public func updateRule(_ rule: AirTrafficRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
            saveSettings()
        }
    }
    
    public func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveSettings()
    }
    
    public func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }
    
    /// Resolves which Space an external incoming URL should open in.
    public func resolveTargetSpace(for url: URL, currentSpaces: [Space], lastActiveSpaceId: UUID) -> UUID {
        // 1. Evaluate explicit rules in priority order
        for rule in rules where rule.isEnabled {
            if rule.matches(url: url) {
                // Ensure target space still exists
                if currentSpaces.contains(where: { $0.id == rule.targetSpaceId }) {
                    return rule.targetSpaceId
                }
            }
        }
        
        // 2. Fallback rule
        switch fallbackMode {
        case .specificSpace:
            if let fallbackId = fallbackSpaceId, currentSpaces.contains(where: { $0.id == fallbackId }) {
                return fallbackId
            }
            return lastActiveSpaceId
        case .mostRecent:
            return lastActiveSpaceId
        }
    }
}

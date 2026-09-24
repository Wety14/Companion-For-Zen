import Foundation

/// Represents a Workspace / Space in Zen Browser (Arc-like workspace organization).
/// Decoupled from UI for direct translation to Android Room entity.
public struct Space: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var iconName: String
    public var themeColorHex: String
    public var order: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        themeColorHex: String = "#537CF7",
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.themeColorHex = themeColorHex
        self.order = order
    }
    
    public static var defaultSpaces: [Space] {
        [
            Space(name: "Personnel", iconName: "person.crop.circle", themeColorHex: "#537CF7", order: 0),
            Space(name: "Travail", iconName: "briefcase", themeColorHex: "#F76F53", order: 1),
            Space(name: "Détente", iconName: "sparkles", themeColorHex: "#2A9D8F", order: 2)
        ]
    }
}

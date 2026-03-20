import Foundation

/// A saved, filled-in parameterized link that triggers immediately
struct Preset: Codable, Identifiable {
    let id: UUID
    let name: String
    let resolvedURL: String
    let originalLinkName: String

    init(id: UUID = UUID(), name: String, resolvedURL: String, originalLinkName: String) {
        self.id = id
        self.name = name
        self.resolvedURL = resolvedURL
        self.originalLinkName = originalLinkName
    }
}

import Foundation

/// Runtime model representing a triggerable deeplink — resolved from config, manual entry, or preset
struct DeepLink: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let scheme: String
    let pathParams: [ParamEntry]
    let queryParams: [ParamEntry]
    let source: Source

    var hasParams: Bool {
        !pathParams.isEmpty || !queryParams.isEmpty
    }

    enum Source: Hashable {
        case config
        case manual
        case preset
    }

    static func from(definition: LinkDefinition, scheme: String) -> DeepLink {
        let pathParams = (definition.params ?? [:]).map { key, value in
            ParamEntry(name: key, defaultValue: value.default)
        }.sorted { $0.name < $1.name }

        let queryParams = (definition.queryParams ?? [:]).map { key, value in
            ParamEntry(name: key, defaultValue: value.default)
        }.sorted { $0.name < $1.name }

        return DeepLink(
            id: UUID(),
            name: definition.name,
            path: definition.path,
            scheme: scheme,
            pathParams: pathParams,
            queryParams: queryParams,
            source: .config
        )
    }

    static func manual(name: String, url: String) -> DeepLink {
        DeepLink(
            id: UUID(),
            name: name,
            path: url,
            scheme: "",
            pathParams: [],
            queryParams: [],
            source: .manual
        )
    }
}

struct ParamEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let defaultValue: String
}

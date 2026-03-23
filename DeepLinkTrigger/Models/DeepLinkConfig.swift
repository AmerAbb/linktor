import Foundation

/// Represents the `.deeplinks.json` file schema
struct DeepLinkConfig: Codable {
    let scheme: String
    let bundleId: String?
    let links: [LinkDefinition]
}

struct LinkDefinition: Codable, Identifiable {
    var id: String { "\(name)|\(path)" }
    let name: String
    let path: String
    let params: [String: ParamDefinition]?
    let queryParams: [String: ParamDefinition]?

    var hasParams: Bool {
        let pathParamCount = params?.count ?? 0
        let queryParamCount = queryParams?.count ?? 0
        return (pathParamCount + queryParamCount) > 0
    }
}

struct ParamDefinition: Codable {
    let type: String
    let `default`: String
}

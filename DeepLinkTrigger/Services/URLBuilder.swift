import Foundation

struct URLBuilder {
    /// Constructs a full deeplink URL from a DeepLink and current param values.
    ///
    /// - Parameters:
    ///   - deepLink: The link template
    ///   - pathValues: Current values for path parameters keyed by param name
    ///   - queryValues: Current values for query parameters keyed by param name
    /// - Returns: The fully constructed URL string
    static func buildURL(
        from deepLink: DeepLink,
        pathValues: [String: String],
        queryValues: [String: String]
    ) -> String {
        // For manual links, the path is already the full URL
        if deepLink.source == .manual {
            return deepLink.path
        }

        var resolvedPath = deepLink.path

        // Substitute path parameters: /product/{productId} → /product/12345
        for param in deepLink.pathParams {
            let value = pathValues[param.name] ?? param.defaultValue
            resolvedPath = resolvedPath.replacingOccurrences(
                of: "{\(param.name)}",
                with: value
            )
        }

        // Build query string
        var queryItems: [String] = []
        for param in deepLink.queryParams {
            let value = queryValues[param.name] ?? param.defaultValue
            if let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryItems.append("\(param.name)=\(encoded)")
            }
        }

        var url = "\(deepLink.scheme)://\(resolvedPath)"
        if !queryItems.isEmpty {
            url += "?" + queryItems.joined(separator: "&")
        }

        return url
    }
}

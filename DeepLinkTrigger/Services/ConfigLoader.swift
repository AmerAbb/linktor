import Foundation

final class ConfigLoader {
    static let configFileName = ".deeplinks.json"

    enum ConfigError: LocalizedError {
        case fileNotFound(String)
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Config file not found at \(path)"
            case .parseError(let message):
                return "Failed to parse config: \(message)"
            }
        }
    }

    func load(from directoryPath: String) throws -> DeepLinkConfig {
        let filePath = (directoryPath as NSString).appendingPathComponent(Self.configFileName)
        let url = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ConfigError.fileNotFound(filePath)
        }

        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(DeepLinkConfig.self, from: data)
            return config
        } catch let error as DecodingError {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }
}

import Foundation

enum Platform {
    case ios
    case android

    var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .android: return "Android"
        }
    }

    var iconName: String {
        switch self {
        case .ios: return "iphone"
        case .android: return "candybarphone"
        }
    }

    /// Detects the project platform by checking for marker files
    static func detect(in directoryPath: String) -> Platform? {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: directoryPath)) ?? []

        let hasIOS = contents.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") || $0 == "Package.swift" }
        let hasAndroid = contents.contains { $0 == "build.gradle" || $0 == "build.gradle.kts" || $0 == "settings.gradle" || $0 == "settings.gradle.kts" }

        // Also check for app/ subdirectory with build.gradle (common Android structure)
        if !hasAndroid {
            let appDir = (directoryPath as NSString).appendingPathComponent("app")
            let appContents = (try? fm.contentsOfDirectory(atPath: appDir)) ?? []
            if appContents.contains(where: { $0 == "build.gradle" || $0 == "build.gradle.kts" }) {
                return .android
            }
        }

        if hasIOS { return .ios }
        if hasAndroid { return .android }
        return nil
    }
}

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
        } catch {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }
}

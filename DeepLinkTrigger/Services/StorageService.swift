import Foundation

final class StorageService {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastProjectPath = "lastProjectPath"
        static func manualLinks(for project: String) -> String {
            "manualLinks_\(project)"
        }
        static func presets(for project: String) -> String {
            "presets_\(project)"
        }
    }

    // MARK: - Project Path

    var lastProjectPath: String? {
        get { defaults.string(forKey: Keys.lastProjectPath) }
        set { defaults.set(newValue, forKey: Keys.lastProjectPath) }
    }

    // MARK: - Manual Links

    struct ManualLink: Codable, Identifiable {
        let id: UUID
        let name: String
        let url: String

        init(id: UUID = UUID(), name: String, url: String) {
            self.id = id
            self.name = name
            self.url = url
        }
    }

    func loadManualLinks(for projectPath: String) -> [ManualLink] {
        guard let data = defaults.data(forKey: Keys.manualLinks(for: projectPath)) else {
            return []
        }
        return (try? JSONDecoder().decode([ManualLink].self, from: data)) ?? []
    }

    func saveManualLinks(_ links: [ManualLink], for projectPath: String) {
        do {
            let data = try JSONEncoder().encode(links)
            defaults.set(data, forKey: Keys.manualLinks(for: projectPath))
        } catch {
            print("Failed to encode manual links: \(error)")
        }
    }

    func addManualLink(name: String, url: String, for projectPath: String) {
        var links = loadManualLinks(for: projectPath)
        links.append(ManualLink(name: name, url: url))
        saveManualLinks(links, for: projectPath)
    }

    func removeManualLink(id: UUID, for projectPath: String) {
        var links = loadManualLinks(for: projectPath)
        links.removeAll { $0.id == id }
        saveManualLinks(links, for: projectPath)
    }

    // MARK: - Presets

    func loadPresets(for projectPath: String) -> [Preset] {
        guard let data = defaults.data(forKey: Keys.presets(for: projectPath)) else {
            return []
        }
        return (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    func savePresets(_ presets: [Preset], for projectPath: String) {
        do {
            let data = try JSONEncoder().encode(presets)
            defaults.set(data, forKey: Keys.presets(for: projectPath))
        } catch {
            print("Failed to encode presets: \(error)")
        }
    }

    func addPreset(_ preset: Preset, for projectPath: String) {
        var presets = loadPresets(for: projectPath)
        presets.append(preset)
        savePresets(presets, for: projectPath)
    }

    func removePreset(id: UUID, for projectPath: String) {
        var presets = loadPresets(for: projectPath)
        presets.removeAll { $0.id == id }
        savePresets(presets, for: projectPath)
    }
}

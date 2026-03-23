import Foundation

struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let platform: Platform
    let type: DeviceType

    enum DeviceType: String, Hashable {
        case simulator
        case physical
    }

    var displayName: String {
        switch type {
        case .physical:
            return "\(name) (Physical)"
        case .simulator:
            let label = platform == .android ? "Emulator" : "Simulator"
            return "\(name) (\(label))"
        }
    }

    /// Sort key: physical devices first, then alphabetical by name
    var sortKey: String {
        let prefix = type == .physical ? "0" : "1"
        return "\(prefix)\(name)"
    }
}

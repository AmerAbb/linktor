import Foundation

final class DeviceService {
    enum DeviceError: LocalizedError {
        case commandFailed(String)
        case adbNotFound
        case deviceCtlNotAvailable
        case bundleIdRequired

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return "Command failed: \(message)"
            case .adbNotFound:
                return "adb not found — is Android SDK installed?"
            case .deviceCtlNotAvailable:
                return "devicectl not found — Xcode 15+ required for physical iOS devices"
            case .bundleIdRequired:
                return "bundleId required in .deeplinks.json for physical iOS devices"
            }
        }
    }

    // MARK: - Device Discovery

    /// Result of a discovery pass. `error` is populated only when no devices were
    /// found *and* a command failed (e.g. Xcode/devicectl/adb missing), so the UI
    /// can explain why the list is empty instead of showing nothing.
    struct DiscoveryResult {
        let devices: [Device]
        let error: String?
    }

    func listDevices(platform: Platform) async -> DiscoveryResult {
        switch platform {
        case .ios:
            return await listIOSDevices()
        case .android:
            return await listAndroidDevices()
        }
    }

    private func listIOSDevices() async -> DiscoveryResult {
        var devices: [Device] = []
        var errors: [String] = []

        // Booted simulators
        do {
            devices += try await listIOSSimulators()
        } catch {
            errors.append("Simulators: \(error.localizedDescription)")
        }

        // Physical devices via devicectl
        do {
            devices += try await listIOSPhysicalDevices()
        } catch {
            errors.append("Physical devices: \(error.localizedDescription)")
        }

        // Only surface an error if we genuinely found nothing — an empty-but-clean
        // result (e.g. no simulator booted) isn't an error worth showing.
        let error = devices.isEmpty && !errors.isEmpty ? errors.joined(separator: "\n") : nil
        return DiscoveryResult(devices: devices.sorted { $0.sortKey < $1.sortKey }, error: error)
    }

    /// Parses `xcrun simctl list devices booted -j`.
    /// JSON structure: top-level `devices` dict keyed by runtime string
    /// (e.g. `com.apple.CoreSimulator.SimRuntime.iOS-18-0`),
    /// each value is an array of device objects with `udid`, `name`, `state` fields.
    private func listIOSSimulators() async throws -> [Device] {
        let output = try await runProcess(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "booted", "-j"]
        )

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesDict = json["devices"] as? [String: [[String: Any]]] else {
            return []
        }

        var devices: [Device] = []
        for (_, runtimeDevices) in devicesDict {
            for device in runtimeDevices {
                guard let udid = device["udid"] as? String,
                      let name = device["name"] as? String,
                      let state = device["state"] as? String,
                      state == "Booted" else { continue }
                devices.append(Device(
                    id: udid,
                    name: name,
                    platform: .ios,
                    type: .simulator
                ))
            }
        }
        return devices
    }

    /// Parses `xcrun devicectl list devices --json-output <tempfile>`.
    /// devicectl requires writing JSON to a file (not stdout).
    /// JSON structure: `result.devices[]` with `identifier`, `deviceProperties.name`,
    /// `connectionProperties.tunnelState`, `hardwareProperties.platform`.
    /// Filters: platform == "iOS" and tunnelState != "unavailable".
    private func listIOSPhysicalDevices() async throws -> [Device] {
        let tempFile = NSTemporaryDirectory() + "devicectl-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        _ = try await runProcess(
            executable: "/usr/bin/xcrun",
            arguments: ["devicectl", "list", "devices", "--json-output", tempFile]
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: tempFile))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let deviceList = result["devices"] as? [[String: Any]] else {
            return []
        }

        var devices: [Device] = []
        for device in deviceList {
            guard let identifier = device["identifier"] as? String,
                  let props = device["deviceProperties"] as? [String: Any],
                  let name = props["name"] as? String,
                  let hwProps = device["hardwareProperties"] as? [String: Any],
                  let hwPlatform = hwProps["platform"] as? String,
                  hwPlatform == "iOS",
                  let connProps = device["connectionProperties"] as? [String: Any],
                  let tunnelState = connProps["tunnelState"] as? String,
                  tunnelState != "unavailable" else { continue }
            devices.append(Device(
                id: identifier,
                name: name,
                platform: .ios,
                type: .physical
            ))
        }
        return devices
    }

    /// Parses `adb devices -l`.
    /// Serials starting with `emulator-` are emulators.
    /// IP:port format (e.g. `192.168.1.5:5555`) = wireless physical device.
    /// Extracts model name from `model:<name>` field if present.
    private func listAndroidDevices() async -> DiscoveryResult {
        let adbPath: String
        do {
            adbPath = try findADB()
        } catch {
            return DiscoveryResult(devices: [], error: error.localizedDescription)
        }

        let output: String
        do {
            output = try await runProcess(executable: adbPath, arguments: ["devices", "-l"])
        } catch {
            return DiscoveryResult(devices: [], error: error.localizedDescription)
        }

        var devices: [Device] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("List of"),
                  trimmed.contains("device") else { continue }

            let parts = trimmed.components(separatedBy: .whitespaces)
            guard let serial = parts.first, parts.count >= 2 else { continue }

            let model = parts.first(where: { $0.hasPrefix("model:") })?
                .replacingOccurrences(of: "model:", with: "")
                .replacingOccurrences(of: "_", with: " ")
                ?? serial

            let isEmulator = serial.hasPrefix("emulator-")
            devices.append(Device(
                id: serial,
                name: model,
                platform: .android,
                type: isEmulator ? .simulator : .physical
            ))
        }
        return DiscoveryResult(devices: devices.sorted { $0.sortKey < $1.sortKey }, error: nil)
    }

    // MARK: - URL Opening

    @discardableResult
    func openURL(_ urlString: String, device: Device, bundleId: String?) async throws -> String {
        switch (device.platform, device.type) {
        case (.ios, .simulator):
            return try await runProcess(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "openurl", device.id, urlString]
            )
        case (.ios, .physical):
            guard let bundleId = bundleId, !bundleId.isEmpty else {
                throw DeviceError.bundleIdRequired
            }
            return try await runProcess(
                executable: "/usr/bin/xcrun",
                arguments: [
                    "devicectl", "device", "process", "launch",
                    "--device", device.id,
                    "--payload-url", urlString,
                    bundleId
                ]
            )
        case (.android, _):
            let adbPath = try findADB()
            return try await runProcess(
                executable: adbPath,
                arguments: [
                    "-s", device.id,
                    "shell", "am", "start",
                    "-a", "android.intent.action.VIEW",
                    "-d", urlString
                ]
            )
        }
    }

    // MARK: - Helpers

    private func findADB() throws -> String {
        let candidates = [
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        if let whichResult = try? runProcessSync(executable: "/usr/bin/which", arguments: ["adb"]),
           !whichResult.isEmpty {
            return whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw DeviceError.adbNotFound
    }

    private func runProcessSync(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    @discardableResult
    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            var outputData = Data()
            var errorData = Data()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.terminationHandler = { proc in
                group.notify(queue: .global()) {
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                    if proc.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        let message = errorOutput.isEmpty ? output : errorOutput
                        continuation.resume(throwing: DeviceError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForWriting.closeFile()
                errorPipe.fileHandleForWriting.closeFile()
                group.notify(queue: .global()) {
                    continuation.resume(throwing: DeviceError.commandFailed(error.localizedDescription))
                }
            }
        }
    }
}

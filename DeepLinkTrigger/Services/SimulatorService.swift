import Foundation

final class SimulatorService {
    enum DeviceError: LocalizedError {
        case commandFailed(String)
        case adbNotFound

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return "Command failed: \(message)"
            case .adbNotFound:
                return "adb not found — is Android SDK installed?"
            }
        }
    }

    /// Opens a URL on a device using the appropriate platform command
    @discardableResult
    func openURL(_ urlString: String, platform: Platform) async throws -> String {
        switch platform {
        case .ios:
            return try await runProcess(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "openurl", "booted", urlString]
            )
        case .android:
            let adbPath = try findADB()
            return try await runProcess(
                executable: adbPath,
                arguments: ["shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", urlString]
            )
        }
    }

    private func findADB() throws -> String {
        // Check common locations
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

        // Try which
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
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(throwing: DeviceError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: DeviceError.commandFailed(error.localizedDescription))
            }
        }
    }
}

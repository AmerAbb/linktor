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
        // Read before waitUntilExit to drain the pipe buffer
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
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
            // Drain pipes concurrently on background threads to prevent
            // pipe buffer deadlock (~64KB buffer can block the process)
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
                // Close write ends so the background reads unblock
                pipe.fileHandleForWriting.closeFile()
                errorPipe.fileHandleForWriting.closeFile()
                group.notify(queue: .global()) {
                    continuation.resume(throwing: DeviceError.commandFailed(error.localizedDescription))
                }
            }
        }
    }
}

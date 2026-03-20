import Foundation

final class SimulatorService {
    enum SimulatorError: LocalizedError {
        case commandFailed(String)
        case noBootedSimulator

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return "Simulator command failed: \(message)"
            case .noBootedSimulator:
                return "No booted simulator found"
            }
        }
    }

    /// Opens a URL on the first booted simulator
    @discardableResult
    func openURL(_ urlString: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "openurl", "booted", urlString]

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
                    continuation.resume(throwing: SimulatorError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: SimulatorError.commandFailed(error.localizedDescription))
            }
        }
    }
}

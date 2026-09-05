import Foundation

struct CommandResult: Sendable {
    let status: Int32
    let standardOutput: String
    let standardError: String

    var combinedOutput: String {
        [standardOutput, standardError]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CommandRunner {
    static func run(_ executable: String, arguments: [String] = []) -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
            return CommandResult(
                status: process.terminationStatus,
                standardOutput: String(decoding: output, as: UTF8.self),
                standardError: String(decoding: error, as: UTF8.self)
            )
        } catch {
            return CommandResult(status: -1, standardOutput: "", standardError: error.localizedDescription)
        }
    }
}


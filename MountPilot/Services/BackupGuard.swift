import Foundation

struct GuardCheck: Sendable, Equatable {
    let isSafe: Bool
    let reason: String?

    static let safe = GuardCheck(isSafe: true, reason: nil)
}

enum BackupGuard {
    static let carbonCopyClonerPaths = [
        "/Applications/Carbon Copy Cloner.app/Contents/MacOS/ccc",
        "/Applications/Carbon Copy Cloner 6.app/Contents/MacOS/ccc"
    ]

    static func check(processTerms: [String]) -> GuardCheck {
        let timeMachine = CommandRunner.run("/usr/bin/tmutil", arguments: ["status"])
        if timeMachine.status != 0 {
            return GuardCheck(isSafe: false, reason: "Time Machine status could not be verified")
        }
        if timeMachine.standardOutput.range(of: #"Running\s*=\s*1"#, options: .regularExpression) != nil {
            return GuardCheck(isSafe: false, reason: "Time Machine is running")
        }
        guard timeMachine.standardOutput.range(of: #"Running\s*=\s*0"#, options: .regularExpression) != nil else {
            return GuardCheck(isSafe: false, reason: "Time Machine returned an unrecognized status")
        }

        for cccPath in carbonCopyClonerPaths where FileManager.default.isExecutableFile(atPath: cccPath) {
            let ccc = CommandRunner.run(cccPath, arguments: ["--no-running-tasks"])
            if ccc.status != 0 {
                return GuardCheck(isSafe: false, reason: "Carbon Copy Cloner is running a task or its status is unavailable")
            }
        }

        let terms = processTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !terms.isEmpty {
            let processes = CommandRunner.run("/bin/ps", arguments: ["-axo", "comm=,args="])
            guard processes.status == 0 else {
                return GuardCheck(isSafe: false, reason: "Running backup processes could not be verified")
            }
            let processList = processes.standardOutput.lowercased()
            if let matched = terms.first(where: { processList.contains($0.lowercased()) }) {
                return GuardCheck(isSafe: false, reason: "A backup process matching “\(matched)” is running")
            }
        }

        return .safe
    }
}

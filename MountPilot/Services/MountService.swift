import AppKit
import Foundation

struct OperationOutcome: Sendable {
    let succeeded: Bool
    let message: String
}

enum MountService {
    static func mountShare(_ value: String) -> OperationOutcome {
        guard AppConfiguration.validShare(value) else {
            return OperationOutcome(succeeded: false, message: "Invalid network share: \(value)")
        }
        let result = CommandRunner.run("/usr/bin/open", arguments: ["-g", value])
        if result.status == 0 {
            return OperationOutcome(succeeded: true, message: "Connection requested for \(value)")
        }
        let detail = result.combinedOutput.isEmpty ? "macOS could not open the share" : result.combinedOutput
        return OperationOutcome(succeeded: false, message: "Could not connect to \(value): \(detail)")
    }

    static func unmountVolume(_ value: String) -> OperationOutcome {
        guard let path = AppConfiguration.volumePath(for: value) else {
            return OperationOutcome(succeeded: false, message: "Invalid volume target: \(value)")
        }
        guard FileManager.default.fileExists(atPath: path) else {
            return OperationOutcome(succeeded: true, message: "Already unmounted: \(path)")
        }

        // Deliberately omit diskutil's `force` option. A backup app or any other
        // process with a live claim can veto this request through Disk Arbitration.
        let result = CommandRunner.run("/usr/sbin/diskutil", arguments: ["unmount", path])
        if result.status == 0 {
            return OperationOutcome(succeeded: true, message: "Unmounted \(path)")
        }
        let detail = result.combinedOutput.isEmpty ? "the volume is busy" : result.combinedOutput
        return OperationOutcome(succeeded: false, message: "Left \(path) mounted: \(detail)")
    }
}

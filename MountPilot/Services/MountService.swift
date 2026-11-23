import AppKit
import Foundation
import NetFS

struct OperationOutcome: Sendable {
    let succeeded: Bool
    let message: String
}

enum MountService {
    /// Connects a share in the background using credentials already saved in
    /// Keychain. No dialog is shown. If macOS has no saved credentials for the
    /// server, MountPilot falls back to Finder's normal connection dialog so the
    /// password can be entered once and saved.
    static func mountShare(_ value: String, allowFinderPrompt: Bool = true) -> OperationOutcome {
        guard let url = AppConfiguration.shareURL(for: value) else {
            return OperationOutcome(succeeded: false, message: "Invalid network share: \(value)")
        }

        let result = mountSilently(url)
        switch result.status {
        case 0:
            let location = result.mountpoints.first.map { " at \($0)" } ?? ""
            return OperationOutcome(succeeded: true, message: "Connected \(value)\(location)")
        case EEXIST:
            return OperationOutcome(succeeded: true, message: "Already connected: \(value)")
        case ENOENT:
            return OperationOutcome(succeeded: false, message: "Could not connect to \(value): the server has no share by that name")
        case EHOSTUNREACH, ENETUNREACH, EHOSTDOWN, ETIMEDOUT, ECONNREFUSED, ENETDOWN:
            return OperationOutcome(succeeded: false, message: "Could not connect to \(value): the server is unreachable")
        default:
            break
        }

        guard isCredentialFailure(result.status) else {
            return OperationOutcome(succeeded: false, message: "Could not connect to \(value): \(describe(result.status))")
        }

        guard allowFinderPrompt else {
            return OperationOutcome(
                succeeded: false,
                message: "Could not reconnect \(value): no saved Keychain password. Use Run Now to enter it."
            )
        }

        // No usable Keychain credentials. Let Finder ask once so the user can
        // save the password; later runs will then connect silently.
        let finder = CommandRunner.run("/usr/bin/open", arguments: ["-g", url.absoluteString])
        if finder.status == 0 {
            return OperationOutcome(
                succeeded: false,
                message: "No saved Keychain password for \(value); Finder is asking for it. Save it so future connections are silent."
            )
        }
        let detail = finder.combinedOutput.isEmpty ? "macOS could not open the share" : finder.combinedOutput
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

    /// Reports whether a share is currently in the mount table. Uses getfsstat
    /// with MNT_NOWAIT so a dead server can never hang the check. Hidden mounts
    /// (such as Time Machine's private copy under /Volumes/.timemachine) do not
    /// count, because they disappear when a backup ends.
    static func isShareMounted(_ value: String) -> Bool {
        guard let key = AppConfiguration.shareKey(for: value) else { return false }
        return mountedShareKeys().contains(key)
    }

    static func mountedShareKeys() -> Set<String> {
        var entries: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&entries, MNT_NOWAIT)
        guard count > 0, let entries else { return [] }

        var keys = Set<String>()
        for index in 0..<Int(count) {
            var entry = entries[index]
            if entry.f_flags & UInt32(MNT_DONTBROWSE) != 0 { continue }
            let type = withUnsafeBytes(of: &entry.f_fstypename) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            guard ["smbfs", "afpfs", "nfs"].contains(type) else { continue }
            let source = withUnsafeBytes(of: &entry.f_mntfromname) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            if let key = AppConfiguration.shareKey(for: source) {
                keys.insert(key)
            }
        }
        return keys
    }

    // MARK: - NetFS

    private struct NetFSResult {
        let status: Int32
        let mountpoints: [String]
    }

    private static func mountSilently(_ url: URL) -> NetFSResult {
        let openOptions = NSMutableDictionary()
        openOptions[kNAUIOptionKey] = kNAUIOptionNoUI

        let mountOptions = NSMutableDictionary()
        mountOptions[kNetFSAllowSubMountsKey] = true
        mountOptions[kNetFSMountAtMountDirKey] = false

        var mountpoints: Unmanaged<CFArray>?
        let status = NetFSMountURLSync(
            url as CFURL,
            nil,
            nil,
            nil,
            openOptions,
            mountOptions,
            &mountpoints
        )
        let paths = mountpoints?.takeRetainedValue() as? [String] ?? []
        return NetFSResult(status: status, mountpoints: paths)
    }

    /// NetFS reports missing or rejected credentials as POSIX auth errors or as
    /// NetAuth OSStatus codes (see NetFS.h). Any of these mean a dialog is needed.
    private static func isCredentialFailure(_ status: Int32) -> Bool {
        switch status {
        case EAUTH, EACCES, EPERM:
            return true
        case -5045, -5046, -5999, -5997, -6600, -6602:
            return true
        default:
            return false
        }
    }

    private static func describe(_ status: Int32) -> String {
        if status > 0, let text = strerror(status) {
            return "\(String(cString: text)) (\(status))"
        }
        return "NetFS error \(status)"
    }
}

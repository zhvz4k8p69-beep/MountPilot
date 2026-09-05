import Foundation

struct AppConfiguration: Codable, Equatable {
    var networkShares: [String] = []
    var cloneVolumes: [String] = []
    var backupProcessTerms: [String] = []
    var startupDelaySeconds: Int = 20
    var runAtLogin: Bool = false

    static let `default` = AppConfiguration()

    static func normalizedLines(_ text: String) -> [String] {
        var seen = Set<String>()
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    static func validShare(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return ["smb", "afp", "nfs"].contains(scheme) && url.host != nil
    }

    static func volumePath(for value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\0") else { return nil }

        let candidate: String
        if trimmed.hasPrefix("/") {
            candidate = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        } else {
            candidate = URL(fileURLWithPath: "/Volumes").appendingPathComponent(trimmed).standardizedFileURL.path
        }

        guard candidate.hasPrefix("/Volumes/"), candidate != "/Volumes" else { return nil }
        return candidate
    }
}

struct ActivityEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let kind: Kind
    let message: String

    enum Kind: Equatable {
        case info
        case success
        case warning
        case failure
    }
}


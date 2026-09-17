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
        shareURL(for: value) != nil
    }

    /// Builds a mountable URL for a share address. Spaces in share names such as
    /// `smb://nas/Time Machine` are percent-encoded so NetFS accepts them.
    static func shareURL(for value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.formUnion(.urlHostAllowed)
        allowed.formUnion(.urlUserAllowed)
        allowed.insert(charactersIn: ":@%")
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: encoded),
              let scheme = url.scheme?.lowercased(),
              ["smb", "afp", "nfs"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
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


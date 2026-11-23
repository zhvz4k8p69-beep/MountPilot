import Foundation

struct AppConfiguration: Codable, Equatable {
    var networkShares: [String] = []
    var cloneVolumes: [String] = []
    var backupProcessTerms: [String] = []
    var startupDelaySeconds: Int = 20
    var runAtLogin: Bool = false
    /// How often to confirm network shares are still mounted. 0 turns it off.
    var recheckIntervalMinutes: Int = 5

    static let `default` = AppConfiguration()

    init(
        networkShares: [String] = [],
        cloneVolumes: [String] = [],
        backupProcessTerms: [String] = [],
        startupDelaySeconds: Int = 20,
        runAtLogin: Bool = false,
        recheckIntervalMinutes: Int = 5
    ) {
        self.networkShares = networkShares
        self.cloneVolumes = cloneVolumes
        self.backupProcessTerms = backupProcessTerms
        self.startupDelaySeconds = startupDelaySeconds
        self.runAtLogin = runAtLogin
        self.recheckIntervalMinutes = recheckIntervalMinutes
    }

    /// Tolerates keys missing from settings saved by older versions, so adding
    /// a field never resets the user's configuration.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppConfiguration()
        networkShares = try c.decodeIfPresent([String].self, forKey: .networkShares) ?? fallback.networkShares
        cloneVolumes = try c.decodeIfPresent([String].self, forKey: .cloneVolumes) ?? fallback.cloneVolumes
        backupProcessTerms = try c.decodeIfPresent([String].self, forKey: .backupProcessTerms) ?? fallback.backupProcessTerms
        startupDelaySeconds = try c.decodeIfPresent(Int.self, forKey: .startupDelaySeconds) ?? fallback.startupDelaySeconds
        runAtLogin = try c.decodeIfPresent(Bool.self, forKey: .runAtLogin) ?? fallback.runAtLogin
        recheckIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .recheckIntervalMinutes) ?? fallback.recheckIntervalMinutes
    }

    /// Reduces a share address or a mount source such as
    /// `//user@DS420/Mac%20Studio%20Time%20Machine` to a comparable
    /// "host/path" key: no scheme, no user, case-insensitive, percent-decoded.
    static func shareKey(for value: String) -> String? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "://") {
            text = String(text[range.upperBound...])
        } else if text.hasPrefix("//") {
            text = String(text.dropFirst(2))
        } else if let colon = text.range(of: ":/") {
            // NFS mount source: host:/export
            text = text.replacingCharacters(in: colon, with: "/")
        }
        guard let slash = text.firstIndex(of: "/") else { return nil }
        var host = String(text[..<slash])
        if let at = host.lastIndex(of: "@") {
            host = String(host[host.index(after: at)...])
        }
        if let colon = host.firstIndex(of: ":") {
            host = String(host[..<colon])
        }
        var path = String(text[text.index(after: slash)...])
        path = path.removingPercentEncoding ?? path
        while path.hasSuffix("/") { path.removeLast() }
        guard !host.isEmpty, !path.isEmpty else { return nil }
        return "\(host)/\(path)".lowercased()
    }

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


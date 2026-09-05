import Foundation

final class ConfigurationStore {
    private let defaults: UserDefaults
    private let key = "MountPilot.configuration.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppConfiguration {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            return .default
        }
        return value
    }

    func save(_ configuration: AppConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: key)
    }
}


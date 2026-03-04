import Foundation

// MARK: - Config Manager

/// Manages user preferences stored in ~/.scrollsense.json
public final class ConfigManager {
    public static let shared = ConfigManager()

    private let configURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configURL = home.appendingPathComponent(".scrollsense.json")
    }

    /// The path to the configuration file.
    public var configPath: String {
        return configURL.path
    }

    /// Load preferences from disk. Returns default preferences if file doesn't exist or is invalid.
    public func load() -> ScrollPreferences {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            let defaultConfig = ScrollPreferences.default
            save(defaultConfig)
            return defaultConfig
        }

        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(ScrollPreferences.self, from: data)
            return config
        } catch {
            Logger.warning("Failed to load config: \(error.localizedDescription). Using defaults.")
            let defaultConfig = ScrollPreferences.default
            save(defaultConfig)
            return defaultConfig
        }
    }

    /// Save preferences to disk with pretty-printed JSON.
    @discardableResult
    public func save(_ config: ScrollPreferences) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
            return true
        } catch {
            Logger.error("Failed to save config: \(error.localizedDescription)")
            return false
        }
    }

    /// Reset preferences to defaults.
    @discardableResult
    public func reset() -> ScrollPreferences {
        let defaultConfig = ScrollPreferences.default
        save(defaultConfig)
        return defaultConfig
    }
}

import Foundation

struct DeviceCacheSnapshot: Codable, Sendable {
    var version = 1
    var sessionKey: String
    var devices: [ThinQDevice]
    var profiles: [String: DeviceProfile]
    var statuses: [String: DeviceStatus]
    var syncIssues: [DeviceSyncIssue]
    var lastSync: Date?
    var rateLimitedUntil: Date?
    var profileBackoffUntil: [String: Date]
    var statusBackoffUntil: [String: Date]
}

struct DeviceCacheStore {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load(sessionKey: String) -> DeviceCacheSnapshot? {
        let url = cacheURL(sessionKey: sessionKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let snapshot = try decoder.decode(DeviceCacheSnapshot.self, from: data)
            AppLog.cache.info("Loaded device cache: \(snapshot.devices.count, privacy: .public) devices, \(snapshot.profiles.count, privacy: .public) profiles, \(snapshot.statuses.count, privacy: .public) statuses")
            return snapshot
        } catch {
            AppLog.cache.error("Failed to decode device cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(_ snapshot: DeviceCacheSnapshot) {
        do {
            let url = cacheURL(sessionKey: snapshot.sessionKey)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            AppLog.cache.info("Saved device cache: \(snapshot.devices.count, privacy: .public) devices, \(snapshot.profiles.count, privacy: .public) profiles, \(snapshot.statuses.count, privacy: .public) statuses")
        } catch {
            AppLog.cache.error("Failed to save device cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear(sessionKey: String) {
        do {
            let url = cacheURL(sessionKey: sessionKey)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            AppLog.cache.info("Cleared device cache")
        } catch {
            AppLog.cache.error("Failed to clear device cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clearAll() {
        do {
            let url = cacheDirectoryURL()
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            AppLog.cache.info("Cleared all device cache files")
        } catch {
            AppLog.cache.error("Failed to clear all device cache files: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sessionKey(country: ThinQCountry, clientID: String) -> String {
        "\(country.rawValue)-\(clientID)"
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
    }

    private func cacheURL(sessionKey: String) -> URL {
        cacheDirectoryURL().appendingPathComponent("\(sessionKey).json")
    }

    private func cacheDirectoryURL() -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("ThinkQ", isDirectory: true)
            .appendingPathComponent("DeviceCache", isDirectory: true)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class ThinQSessionStore {
    enum MenuBarMode: String, CaseIterable, Identifiable {
        case fullAppAndMenuBar
        case menuBarFirst
        case dockOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fullAppAndMenuBar: "Full App + Menu Bar"
            case .menuBarFirst: "Menu Bar First"
            case .dockOnly: "Dock Only"
            }
        }
    }

    private enum DefaultsKey {
        static let country = "session.country"
        static let clientID = "session.clientID"
        static let refreshInterval = "preferences.refreshInterval"
        static let menuBarMode = "preferences.menuBarMode"
        static let comfortableDensity = "preferences.comfortableDensity"
        static let notifications = "preferences.notifications"
        static let backgroundNotifications = "preferences.backgroundNotifications"
        static let onboardingCompleted = "onboarding.completed"
    }

    private let keychain = KeychainStore(service: "com.xavier.thinkq")
    private let tokenAccount = "thinq-personal-access-token"
    private let defaults: UserDefaults

    var country: ThinQCountry {
        didSet { defaults.set(country.rawValue, forKey: DefaultsKey.country) }
    }

    var clientID: String {
        didSet { defaults.set(clientID, forKey: DefaultsKey.clientID) }
    }

    var personalAccessToken: String = ""
    var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: DefaultsKey.refreshInterval) }
    }

    var menuBarMode: MenuBarMode {
        didSet { defaults.set(menuBarMode.rawValue, forKey: DefaultsKey.menuBarMode) }
    }

    var comfortableDensity: Bool {
        didSet { defaults.set(comfortableDensity, forKey: DefaultsKey.comfortableDensity) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: DefaultsKey.notifications) }
    }

    var backgroundNotificationsEnabled: Bool {
        didSet { defaults.set(backgroundNotificationsEnabled, forKey: DefaultsKey.backgroundNotifications) }
    }

    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: DefaultsKey.onboardingCompleted) }
    }

    var hasToken: Bool {
        !personalAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var region: ThinQRegion {
        country.region
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let countryCode = defaults.string(forKey: DefaultsKey.country) ?? ThinQCountry.US.rawValue
        self.country = ThinQCountry(rawValue: countryCode) ?? .US
        let resolvedClientID = defaults.string(forKey: DefaultsKey.clientID) ?? "thinq-open-\(UUID().uuidString.lowercased())"
        self.clientID = resolvedClientID
        if defaults.string(forKey: DefaultsKey.clientID) == nil {
            defaults.set(resolvedClientID, forKey: DefaultsKey.clientID)
        }
        let interval = defaults.double(forKey: DefaultsKey.refreshInterval)
        self.refreshInterval = interval == 0 ? 120 : interval
        let mode = defaults.string(forKey: DefaultsKey.menuBarMode) ?? MenuBarMode.fullAppAndMenuBar.rawValue
        self.menuBarMode = MenuBarMode(rawValue: mode) ?? .fullAppAndMenuBar
        self.comfortableDensity = defaults.object(forKey: DefaultsKey.comfortableDensity) as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: DefaultsKey.notifications) as? Bool ?? true
        self.backgroundNotificationsEnabled = defaults.object(forKey: DefaultsKey.backgroundNotifications) as? Bool ?? false
        self.onboardingCompleted = defaults.object(forKey: DefaultsKey.onboardingCompleted) as? Bool ?? false
        self.personalAccessToken = (try? keychain.string(for: tokenAccount)) ?? ""
        migrateTokenAccessIfNeeded()
    }

    func saveToken(_ token: String) {
        personalAccessToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if personalAccessToken.isEmpty {
                try keychain.remove(account: tokenAccount)
            } else {
                try keychain.setString(personalAccessToken, for: tokenAccount)
            }
            AppLog.auth.info("Updated ThinQ token presence: \(self.hasToken, privacy: .public)")
        } catch {
            AppLog.auth.error("Failed to update token: \(error.localizedDescription, privacy: .public)")
        }
    }

    func completeOnboarding() {
        onboardingCompleted = true
    }

    private func migrateTokenAccessIfNeeded() {
        guard hasToken else { return }
        do {
            try keychain.setString(personalAccessToken, for: tokenAccount)
            AppLog.auth.info("Refreshed ThinQ token Keychain access")
        } catch {
            AppLog.auth.error("Failed to refresh token Keychain access: \(error.localizedDescription, privacy: .public)")
        }
    }
}

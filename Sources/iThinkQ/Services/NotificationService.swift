import Foundation
import Observation
@preconcurrency import UserNotifications

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    enum AuthorizationState: String {
        case unknown
        case allowed
        case denied
        case provisional

        var title: String {
            switch self {
            case .unknown: "Not Requested"
            case .allowed: "Allowed"
            case .denied: "Denied"
            case .provisional: "Provisional"
            }
        }
    }

    private let center = UNUserNotificationCenter.current()
    var authorizationState: AuthorizationState = .unknown

    override init() {
        super.init()
        center.delegate = self
    }

    func refreshAuthorizationState() async {
        let settings = await center.notificationSettings()
        authorizationState = Self.state(from: settings.authorizationStatus)
    }

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationState = granted ? .allowed : .denied
            AppLog.notifications.info("Notification authorization updated: \(self.authorizationState.rawValue, privacy: .public)")
        } catch {
            authorizationState = .denied
            AppLog.notifications.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deliver(message: LiveEventMessage, devices: [ThinQDevice], enabled: Bool) async {
        guard enabled else { return }
        await refreshAuthorizationState()
        guard authorizationState == .allowed || authorizationState == .provisional else { return }

        let content = UNMutableNotificationContent()
        let deviceName = message.deviceID.flatMap { id in devices.first { $0.id == id }?.displayName }
        content.title = deviceName ?? (message.isPushNotification ? "ThinQ Alert" : "ThinQ Update")
        content.body = message.safeDisplaySummary
        content.sound = .default
        content.threadIdentifier = message.deviceID ?? "thinq-live-events"

        let request = UNNotificationRequest(
            identifier: "thinq-\(message.id.uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            AppLog.notifications.info("Delivered local ThinQ notification")
        } catch {
            AppLog.notifications.error("Failed to deliver notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    private static func state(from status: UNAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .authorized: .allowed
        case .denied: .denied
        case .provisional, .ephemeral: .provisional
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
    }
}

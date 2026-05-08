import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {
    var lastError: String?

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
            AppLog.windowing.info("Launch at login updated: \(enabled, privacy: .public)")
        } catch {
            lastError = error.localizedDescription
            AppLog.windowing.error("Launch at login update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

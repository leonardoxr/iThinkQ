import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class DeviceStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    private let liveClient: ThinQClient
    private let mockClient: ThinQClient
    private let customizationStore: DeviceCustomizationStore
    private let cacheStore: DeviceCacheStore
    private let controlEngine = ControlEngine()
    private var pollingTask: Task<Void, Never>?
    private var currentCacheSessionKey: String?
    private var profileBackoffUntil: [String: Date] = [:]
    private var statusBackoffUntil: [String: Date] = [:]

    var devices: [ThinQDevice] = []
    var profiles: [String: DeviceProfile] = [:]
    var statuses: [String: DeviceStatus] = [:]
    var selection: ThinQDevice.ID?
    var searchText = ""
    var state: LoadState = .idle
    var lastSync: Date?
    var pendingControlIDs: Set<String> = []
    var syncIssues: [DeviceSyncIssue] = []
    var lastControlError: String?
    var lastLiveEventSummary: String?
    var consecutiveRefreshFailures = 0
    var rateLimitedUntil: Date?
    var privacyActionMessage: String?

    init(
        liveClient: ThinQClient = ThinQHTTPClient(),
        mockClient: ThinQClient = MockThinQClient(),
        customizationStore: DeviceCustomizationStore = DeviceCustomizationStore(),
        cacheStore: DeviceCacheStore = DeviceCacheStore()
    ) {
        self.liveClient = liveClient
        self.mockClient = mockClient
        self.customizationStore = customizationStore
        self.cacheStore = cacheStore
    }

    var filteredDevices: [ThinQDevice] {
        guard !searchText.isEmpty else { return devices }
        return devices.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.type.title.localizedCaseInsensitiveContains(searchText)
                || $0.modelName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var favoriteDevices: [ThinQDevice] {
        devices.filter(\.isFavorite)
    }

    var onlineDevices: [ThinQDevice] {
        devices.filter { statuses[$0.id]?.isAvailable ?? false }
    }

    var menuBarDevices: [ThinQDevice] {
        let favorites = onlineDevices.filter(\.isFavorite)
        return favorites.isEmpty ? onlineDevices : favorites
    }

    var userVisibleSyncIssues: [DeviceSyncIssue] {
        syncIssues.filter { !$0.isNonCriticalThinQFeatureGap }
    }

    func listingStatus(for device: ThinQDevice) -> DeviceListingStatus {
        guard let status = statuses[device.id] else {
            return DeviceListingStatus(title: "Unknown", detail: "Waiting for status", symbol: "questionmark.circle", tint: .secondary, isOnline: false, isPoweredOn: false)
        }
        guard status.isAvailable else {
            return DeviceListingStatus(title: "Unavailable", detail: status.unavailableReason ?? "Cannot reach device", symbol: "wifi.slash", tint: .orange, isOnline: false, isPoweredOn: false)
        }

        let power = currentText(for: device, role: .power)
        let mode = currentText(for: device, role: .mode)
        let fan = currentText(for: device, role: .fan)
        let temperature = currentNumber(for: device, role: .temperature)
        let isPoweredOn = !(power ?? "").uppercased().contains("OFF")
        let title = isPoweredOn ? "On" : "Off"

        var detailParts: [String] = []
        if let mode, !mode.isEmpty {
            detailParts.append(mode.thinkQTitleCasedValue)
        }
        if let temperature {
            detailParts.append("\(Int(temperature))°")
        }
        if let fan, device.type == .airConditioner {
            detailParts.append(fan.thinkQTitleCasedValue)
        }

        return DeviceListingStatus(
            title: title,
            detail: detailParts.isEmpty ? "Online" : detailParts.joined(separator: " · "),
            symbol: isPoweredOn ? "power.circle.fill" : "power.circle",
            tint: isPoweredOn ? .green : .secondary,
            isOnline: true,
            isPoweredOn: isPoweredOn
        )
    }

    func loadCachedData(session: ThinQSessionStore) {
        let key = cacheKey(session: session)
        guard currentCacheSessionKey != key else { return }
        currentCacheSessionKey = key
        guard let snapshot = cacheStore.load(sessionKey: key) else { return }

        devices = snapshot.devices.map { customizationStore.apply(to: $0) }
        profiles = snapshot.profiles
        statuses = snapshot.statuses
        syncIssues = snapshot.syncIssues
        lastSync = snapshot.lastSync
        rateLimitedUntil = snapshot.rateLimitedUntil
        profileBackoffUntil = snapshot.profileBackoffUntil
        statusBackoffUntil = snapshot.statusBackoffUntil
        if selection == nil || !devices.contains(where: { $0.id == selection }) {
            selection = devices.first?.id
        }
        state = devices.isEmpty ? .idle : .ready
        AppLog.sync.info("Loaded cached device state")
    }

    func refresh(session: ThinQSessionStore, force: Bool = false) async {
        loadCachedData(session: session)
        if case .loading = state {
            AppLog.sync.info("Skipped refresh because one is already running")
            return
        }
        if let rateLimitedUntil, rateLimitedUntil > Date() {
            AppLog.rateLimit.info("Skipped refresh during rate-limit cooldown")
            state = .failed("LG API limit active until \(rateLimitedUntil.formatted(date: .omitted, time: .shortened)).")
            return
        }
        if !force, let lastSync, Date().timeIntervalSince(lastSync) < 45 {
            AppLog.cache.info("Skipped refresh because cached data is still fresh")
            return
        }

        state = .loading
        let snapshot = ThinQSessionSnapshot(token: session.personalAccessToken, country: session.country, clientID: session.clientID)
        let client = session.hasToken ? liveClient : mockClient
        do {
            AppLog.sync.info("Refreshing devices via \(session.hasToken ? "ThinQ" : "mock", privacy: .public)")
            if force || shouldRefreshDeviceList {
                AppLog.sync.info("Fetching ThinQ device list")
                let fetchedDevices = try await client.fetchDevices(session: snapshot)
                devices = fetchedDevices.map { customizationStore.apply(to: $0) }
            } else {
                AppLog.cache.info("Using cached device list")
            }
            if selection == nil || !devices.contains(where: { $0.id == selection }) {
                selection = devices.first?.id
            }
            try await loadDetails(client: client, snapshot: snapshot, force: force)
            lastSync = Date()
            state = .ready
            consecutiveRefreshFailures = 0
            saveCache(session: session)
        } catch {
            handleRefreshError(error)
            consecutiveRefreshFailures += 1
            saveCache(session: session)
            AppLog.sync.error("Device refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func selectedDevice() -> ThinQDevice? {
        devices.first { $0.id == selection }
    }

    func toggleFavorite(_ device: ThinQDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].isFavorite.toggle()
        customizationStore.setFavorite(devices[index].isFavorite, for: device.id)
    }

    func rename(_ device: ThinQDevice, alias: String) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        customizationStore.setAlias(devices[index].alias, for: device.id)
    }

    func setVisual(_ device: ThinQDevice, symbolName: String?, accentName: String?) {
        customizationStore.setVisual(symbolName: symbolName, accentName: accentName, for: device.id)
    }

    func clearCachedData(session: ThinQSessionStore) {
        cacheStore.clear(sessionKey: cacheKey(session: session))
        profiles = [:]
        statuses = [:]
        syncIssues = []
        lastSync = nil
        rateLimitedUntil = nil
        profileBackoffUntil = [:]
        statusBackoffUntil = [:]
        privacyActionMessage = "Cleared cached device data for this account."
    }

    func sanitizedDiagnostics(session: ThinQSessionStore, liveEventState: String) -> String {
        let groupedDevices = Dictionary(grouping: devices, by: \.type.title)
            .mapValues(\.count)
            .sorted { $0.key < $1.key }
        let onlineCount = devices.filter { statuses[$0.id]?.isAvailable ?? false }.count
        let issueSummaries = syncIssues.prefix(8).map { issue in
            "- \(issue.area): \(issue.userFacingSummary)"
        }

        var lines: [String] = [
            "ThinkQ Diagnostics",
            "Generated: \(Date().formatted(date: .abbreviated, time: .standard))",
            "Country: \(session.country.rawValue)",
            "Region: \(session.region.rawValue)",
            "Has token: \(session.hasToken ? "yes" : "no")",
            "Menu bar mode: \(session.menuBarMode.title)",
            "Refresh interval: \(Int(session.refreshInterval))s",
            "Devices: \(devices.count)",
            "Online devices: \(onlineCount)",
            "Profiles cached: \(profiles.count)",
            "Statuses cached: \(statuses.count)",
            "Last sync: \(lastSync?.formatted(date: .abbreviated, time: .standard) ?? "never")",
            "Live events: \(liveEventState)"
        ]

        if !groupedDevices.isEmpty {
            lines.append("Device families:")
            lines.append(contentsOf: groupedDevices.map { "- \($0.key): \($0.value)" })
        }

        if !issueSummaries.isEmpty {
            lines.append("Sync issues:")
            lines.append(contentsOf: issueSummaries)
        }

        lines.append("No tokens, device IDs, raw payloads, certificates, or private keys are included.")
        return lines.joined(separator: "\n")
    }

    func symbolName(for device: ThinQDevice) -> String {
        customizationStore.symbolName(for: device)
    }

    func accent(for device: ThinQDevice) -> Color {
        Color.thinkQAccent(named: customizationStore.accentName(for: device)) ?? device.type.accent
    }

    func customization(for device: ThinQDevice) -> DeviceCustomization {
        customizationStore.customization(for: device.id)
    }

    func primaryCapability(_ role: DeviceControlRole, for device: ThinQDevice) -> DeviceCapability? {
        let capabilities = profiles[device.id]?.writableCapabilities ?? []
        if role == .temperature {
            return DeviceControlCatalog.primaryTemperatureCapability(
                capabilities: capabilities,
                deviceType: device.type,
                currentMode: currentText(for: device, role: .mode)
            )
        }
        return DeviceControlCatalog.primaryCapability(role, capabilities: capabilities, deviceType: device.type)
    }

    func currentNumber(for device: ThinQDevice, role: DeviceControlRole) -> Double? {
        guard role == .temperature else { return nil }
        let mode = currentText(for: device, role: .mode)?.lowercased() ?? ""
        let preferredKeys: [String]
        if mode.contains("cool") {
            preferredKeys = ["temperature.coolTargetTemperature", "temperature.targetTemperature"]
        } else if mode.contains("auto") || mode.contains("ai") {
            preferredKeys = ["temperature.autoTargetTemperature", "temperature.targetTemperature"]
        } else if mode.contains("heat") {
            preferredKeys = ["temperature.heatTargetTemperature", "temperature.targetTemperature"]
        } else if mode.contains("dry") {
            preferredKeys = ["temperature.dryTargetTemperature", "temperature.targetTemperature"]
        } else {
            preferredKeys = ["temperature.targetTemperature", "temperature.coolTargetTemperature", "temperature.autoTargetTemperature"]
        }
        return statuses[device.id]?.firstNumber(preferredKeys + ["temperatureInUnits[0].targetTemperature"])
    }

    func currentText(for device: ThinQDevice, role: DeviceControlRole) -> String? {
        switch role {
        case .power:
            statuses[device.id]?.firstText("operation.airConOperationMode", "operation.mode", "runState.currentState")
        case .mode:
            statuses[device.id]?.firstText("airConJobMode.currentJobMode", "runState.currentState")
        case .fan:
            statuses[device.id]?.firstText("airFlow.windStrengthDetail", "airFlow.windStrength")
        default:
            nil
        }
    }

    func setPower(_ on: Bool, for device: ThinQDevice, session: ThinQSessionStore) async {
        guard let capability = primaryCapability(.power, for: device) else { return }
        let selectedValue = capability.enumValues.first { value in
            let upper = value.uppercased()
            return on ? (upper.contains("ON") || upper == "START") : (upper.contains("OFF") || upper == "STOP")
        }
        guard let selectedValue else { return }
        await send(capability: capability, value: .string(selectedValue), device: device, session: session)
    }

    func canSendQuickControl(_ role: DeviceControlRole, for device: ThinQDevice) -> Bool {
        guard let capability = primaryCapability(role, for: device) else { return false }
        guard statuses[device.id]?.isAvailable ?? true else { return false }
        return !pendingControlIDs.contains(controlKey(deviceID: device.id, capabilityID: capability.id))
    }

    func isControlPending(_ capability: DeviceCapability, for device: ThinQDevice) -> Bool {
        pendingControlIDs.contains(controlKey(deviceID: device.id, capabilityID: capability.id))
    }

    func adjustTemperature(for device: ThinQDevice, delta: Double, session: ThinQSessionStore) async {
        guard let capability = primaryCapability(.temperature, for: device),
              let range = capability.range
        else { return }
        let current = currentNumber(for: device, role: .temperature) ?? range.min
        let stepped = current + delta
        let clamped = min(range.max, max(range.min, stepped))
        await send(capability: capability, value: .number(clamped), device: device, session: session)
    }

    func startPolling(session: ThinQSessionStore) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let baseInterval = max(30, session.refreshInterval)
                let backoff = min(900, baseInterval * pow(2, Double(consecutiveRefreshFailures)))
                try? await Task.sleep(for: .seconds(backoff))
                if Task.isCancelled { return }
                await self.refresh(session: session)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func applyLiveEvent(_ message: LiveEventMessage) {
        guard let data = message.payload.data(using: .utf8),
              let json = try? JSONDecoder().decode(ThinQJSON.self, from: data)
        else {
            lastLiveEventSummary = message.safeDisplaySummary
            return
        }

        let targetDeviceID = json.firstString(for: ["deviceId", "deviceID", "device_id"])
            ?? devices.first { message.topic.contains($0.id) }?.id

        guard let deviceID = targetDeviceID, devices.contains(where: { $0.id == deviceID }) else {
            lastLiveEventSummary = "Received event for unknown device"
            return
        }

        let stateCandidate = json.firstObject(for: ["state", "status", "snapshot", "report", "data"]) ?? json
        if case .object(let object) = stateCandidate {
            let flattened = DeviceProfileParser.flattenStatus(object)
            if !flattened.isEmpty {
                statuses[deviceID] = DeviceStatus(values: flattened, updatedAt: message.receivedAt)
                lastLiveEventSummary = "Updated \(devices.first { $0.id == deviceID }?.displayName ?? "device") from live event"
                AppLog.sync.info("Applied live event for device")
            }
        }
    }

    func send(capability: DeviceCapability, value: ThinQJSON, device: ThinQDevice, session: ThinQSessionStore) async {
        guard statuses[device.id]?.isAvailable ?? true else {
            lastControlError = statuses[device.id]?.unavailableReason ?? "Device is unavailable."
            return
        }
        let snapshot = ThinQSessionSnapshot(token: session.personalAccessToken, country: session.country, clientID: session.clientID)
        let client = session.hasToken ? liveClient : mockClient
        do {
            let command = try controlEngine.command(deviceID: device.id, capability: capability, value: value)
            let pendingID = controlKey(deviceID: device.id, capabilityID: capability.id)
            pendingControlIDs.insert(pendingID)
            defer { pendingControlIDs.remove(pendingID) }
            lastControlError = nil
            AppLog.control.info("Sending control \(capability.id, privacy: .public)")
            try await client.sendControl(command, session: snapshot)
            let status = try await client.fetchStatus(deviceID: device.id, session: snapshot)
            statuses[device.id] = status
            saveCache(session: session)
        } catch {
            lastControlError = error.localizedDescription
            if isRateLimit(error) {
                activateRateLimitCooldown()
            }
            AppLog.control.error("Control failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadDetails(client: ThinQClient, snapshot: ThinQSessionSnapshot, force: Bool) async throws {
        syncIssues = []
        for device in devices {
            if shouldFetchProfile(for: device, force: force) {
                do {
                    AppLog.sync.info("Fetching profile for \(device.type.rawValue, privacy: .public)")
                    profiles[device.id] = try await client.fetchProfile(deviceID: device.id, session: snapshot)
                    profileBackoffUntil[device.id] = nil
                } catch {
                    if isRateLimit(error) { throw error }
                    profiles[device.id] = DeviceProfile(raw: [:], capabilities: [])
                    syncIssues.append(DeviceSyncIssue(deviceID: device.id, deviceName: device.displayName, area: "Profile", message: error.localizedDescription))
                    if isNonCriticalFeatureGap(error) {
                        profileBackoffUntil[device.id] = Date().addingTimeInterval(24 * 60 * 60)
                    }
                    AppLog.sync.error("Profile unavailable for \(device.type.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            } else {
                AppLog.cache.info("Using cached profile for \(device.type.rawValue, privacy: .public)")
            }

            guard shouldFetchStatus(for: device, force: force) else { continue }
            do {
                AppLog.sync.info("Fetching status for \(device.type.rawValue, privacy: .public)")
                statuses[device.id] = try await client.fetchStatus(deviceID: device.id, session: snapshot)
                statusBackoffUntil[device.id] = nil
            } catch {
                if isRateLimit(error) { throw error }
                statuses[device.id] = DeviceStatus(
                    values: ["connection.error": .string(error.localizedDescription)],
                    updatedAt: Date()
                )
                syncIssues.append(DeviceSyncIssue(deviceID: device.id, deviceName: device.displayName, area: "Status", message: error.localizedDescription))
                if error.localizedDescription.localizedCaseInsensitiveContains("not connected") {
                    statusBackoffUntil[device.id] = Date().addingTimeInterval(5 * 60)
                }
                AppLog.sync.error("Status unavailable for \(device.type.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handleRefreshError(_ error: Error) {
        if isRateLimit(error) {
            activateRateLimitCooldown()
            state = .failed(rateLimitMessage)
        } else {
            state = .failed(error.localizedDescription)
        }
    }

    private func activateRateLimitCooldown() {
        rateLimitedUntil = Date().addingTimeInterval(30 * 60)
        AppLog.rateLimit.error("Activated LG API cooldown until \(self.rateLimitedUntil?.formatted(date: .omitted, time: .standard) ?? "unknown", privacy: .public)")
        stopPolling()
    }

    private var rateLimitMessage: String {
        if let rateLimitedUntil {
            "LG API limit reached. Paused until \(rateLimitedUntil.formatted(date: .omitted, time: .shortened))."
        } else {
            "LG API limit reached. ThinkQ paused requests."
        }
    }

    private func isRateLimit(_ error: Error) -> Bool {
        (error as? ThinQAPIError)?.isRateLimit == true
    }

    private var shouldRefreshDeviceList: Bool {
        devices.isEmpty || lastSync.map { Date().timeIntervalSince($0) > 60 * 60 } ?? true
    }

    private func shouldFetchProfile(for device: ThinQDevice, force: Bool) -> Bool {
        if !force, let backoff = profileBackoffUntil[device.id], backoff > Date() {
            return false
        }
        if force { return true }
        guard let profile = profiles[device.id] else { return true }
        return profile.capabilities.isEmpty && (profileBackoffUntil[device.id] ?? .distantPast) <= Date()
    }

    private func shouldFetchStatus(for device: ThinQDevice, force: Bool) -> Bool {
        if !force, let backoff = statusBackoffUntil[device.id], backoff > Date() {
            return false
        }
        guard !force, let status = statuses[device.id] else { return true }
        return Date().timeIntervalSince(status.updatedAt) > 60
    }

    private func isNonCriticalFeatureGap(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("not provided feature")
            || message.contains("unsupported feature")
            || message.contains("not supported")
    }

    private func cacheKey(session: ThinQSessionStore) -> String {
        cacheStore.sessionKey(country: session.country, clientID: session.clientID)
    }

    private func controlKey(deviceID: String, capabilityID: String) -> String {
        "\(deviceID)|\(capabilityID)"
    }

    private func saveCache(session: ThinQSessionStore) {
        let key = cacheKey(session: session)
        currentCacheSessionKey = key
        cacheStore.save(DeviceCacheSnapshot(
            sessionKey: key,
            devices: devices,
            profiles: profiles,
            statuses: statuses,
            syncIssues: syncIssues,
            lastSync: lastSync,
            rateLimitedUntil: rateLimitedUntil,
            profileBackoffUntil: profileBackoffUntil,
            statusBackoffUntil: statusBackoffUntil
        ))
    }
}

struct DeviceListingStatus: Hashable {
    var title: String
    var detail: String
    var symbol: String
    var tint: Color
    var isOnline: Bool
    var isPoweredOn: Bool
}

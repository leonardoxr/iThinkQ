import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    @Environment(LiveEventService.self) private var liveEventService
    @Environment(NotificationService.self) private var notificationService
    @Environment(LaunchAtLoginService.self) private var launchAtLoginService
    @State private var tokenDraft = ""
    @State private var isTestingToken = false
    @State private var tokenTestMessage: String?
    @State private var tokenTestSucceeded = false

    var body: some View {
        @Bindable var session = session
        Form {
            Section("Account") {
                SecureField("ThinQ Personal Access Token", text: $tokenDraft)
                    .onAppear { tokenDraft = session.personalAccessToken }
                HStack {
                    Button("Test Token") {
                        Task { await testToken() }
                    }
                    .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTestingToken)

                    Button("Save Token") {
                        session.saveToken(tokenDraft)
                        session.completeOnboarding()
                        Task { await deviceStore.refresh(session: session) }
                    }
                    Button("Clear") {
                        tokenDraft = ""
                        session.saveToken("")
                    }
                }
                if let tokenTestMessage {
                    Label(tokenTestMessage, systemImage: tokenTestSucceeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.caption)
                        .foregroundStyle(tokenTestSucceeded ? .green : .red)
                }
                Picker("Country", selection: $session.country) {
                    ForEach(ThinQCountry.allCases) { country in
                        Text(country.rawValue).tag(country)
                    }
                }
                Text("Region: \(session.region.rawValue.uppercased())")
                    .foregroundStyle(.secondary)
            }

            Section("Experience") {
                Picker("Menu Bar", selection: $session.menuBarMode) {
                    ForEach(ThinQSessionStore.MenuBarMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Comfortable density", isOn: $session.comfortableDensity)
                Toggle("Notifications", isOn: $session.notificationsEnabled)
                    .onChange(of: session.notificationsEnabled) { _, enabled in
                        if enabled {
                            Task { await notificationService.requestAuthorization() }
                        }
                    }
                Toggle("Keep notifications alive at login", isOn: backgroundNotificationsBinding)
                Text("Starts iThinkQ at login so the menu bar app can keep the ThinQ MQTT stream connected. Notifications cannot arrive when no iThinkQ process is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = launchAtLoginService.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                LabeledContent("Notification permission", value: notificationService.authorizationState.title)
                Slider(value: $session.refreshInterval, in: 30...600, step: 30) {
                    Text("Refresh")
                }
                Text("Refresh every \(Int(session.refreshInterval)) seconds")
                    .foregroundStyle(.secondary)
            }

            Section("Sync") {
                LabeledContent("Last refresh", value: deviceStore.lastSync?.formatted(date: .omitted, time: .standard) ?? "Never")
                LabeledContent("Refresh failures", value: "\(deviceStore.consecutiveRefreshFailures)")
                if let summary = deviceStore.lastLiveEventSummary {
                    LabeledContent("Last live event", value: summary)
                }
                if deviceStore.syncIssues.isEmpty {
                    Label("No current device sync issues", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    ForEach(deviceStore.syncIssues.prefix(6)) { issue in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(issue.deviceName) \(issue.area)")
                                .font(.headline)
                            Text(issue.userFacingSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Live Events") {
                LabeledContent("Status", value: liveEventService.state.title)
                switch liveEventService.state {
                case .ready(let route):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route)
                        Text("\(liveEventService.certificateBundle?.subscriptions.count ?? 0) MQTT topic subscription\(liveEventService.certificateBundle?.subscriptions.count == 1 ? "" : "s") prepared")
                    }
                        .foregroundStyle(.secondary)
                case .connected(let host):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host)
                        Text("Listening for ThinQ device status changes.")
                    }
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)
                default:
                    EmptyView()
                }
                LabeledContent("Reportable devices", value: "\(liveEventService.reportableDeviceCount)")
                LabeledContent("Connection attempts", value: "\(liveEventService.connectionAttempts)")
                if let connectedAt = liveEventService.connectedAt {
                    LabeledContent("Connected since", value: connectedAt.formatted(date: .omitted, time: .standard))
                }
                if let lastMessageAt = liveEventService.lastMessageAt {
                    LabeledContent("Last message", value: lastMessageAt.formatted(date: .omitted, time: .standard))
                }
                if let lastDisconnectedAt = liveEventService.lastDisconnectedAt {
                    LabeledContent("Last disconnect", value: lastDisconnectedAt.formatted(date: .omitted, time: .standard))
                }
                if let retryAfter = liveEventService.retryAfter {
                    LabeledContent("Next retry", value: retryAfter.formatted(date: .omitted, time: .standard))
                }
                if let nextRenewal = liveEventService.nextSubscriptionRenewalAt {
                    LabeledContent("Subscription renewal", value: nextRenewal.formatted(date: .omitted, time: .shortened))
                }
                Button {
                    Task { await liveEventService.prepare(session: session, devices: deviceStore.devices) }
                } label: {
                    Label("Prepare Event Client", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(!session.hasToken || deviceStore.devices.isEmpty)

                Button {
                    Task { await liveEventService.connect(session: session) }
                } label: {
                    Label("Connect MQTT Stream", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(!session.hasToken || liveEventsConnected)

                Button {
                    Task { await liveEventService.disconnect() }
                } label: {
                    Label("Disconnect MQTT", systemImage: "xmark.circle")
                }

                if !liveEventService.recentMessages.isEmpty {
                    ForEach(liveEventService.recentMessages.prefix(3)) { message in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.safeDisplayTitle)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("\(message.safeDisplaySummary) \(message.receivedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Privacy") {
                Text("iThinkQ stores your token in Keychain and does not write tokens or raw personal device data to logs.")
                    .foregroundStyle(.secondary)
                Button {
                    copySanitizedDiagnostics()
                } label: {
                    Label("Copy Sanitized Diagnostics", systemImage: "doc.on.clipboard")
                }
                Button(role: .destructive) {
                    deviceStore.clearCachedData(session: session)
                } label: {
                    Label("Clear Cached Device Data", systemImage: "trash")
                }
                if let message = deviceStore.privacyActionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Developer Reference") {
                LabeledContent("Source", value: APIReference.thinQConnectTitle)
                Button {
                    NSWorkspace.shared.open(APIReference.thinQConnectDeveloperPortal)
                } label: {
                    Label("Open ThinQ Connect API", systemImage: "safari")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testToken() async {
        let token = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        isTestingToken = true
        tokenTestMessage = nil
        defer { isTestingToken = false }

        do {
            let client = ThinQHTTPClient()
            let snapshot = ThinQSessionSnapshot(token: token, country: session.country, clientID: session.clientID)
            let devices = try await client.fetchDevices(session: snapshot)
            tokenTestSucceeded = true
            tokenTestMessage = "Token works. Found \(devices.count) device\(devices.count == 1 ? "" : "s")."
        } catch {
            tokenTestSucceeded = false
            tokenTestMessage = error.localizedDescription
        }
    }

    private var backgroundNotificationsBinding: Binding<Bool> {
        Binding {
            session.backgroundNotificationsEnabled
        } set: { newValue in
            session.backgroundNotificationsEnabled = newValue
            launchAtLoginService.setEnabled(newValue)
            if newValue {
                session.menuBarMode = .menuBarFirst
                Task { await notificationService.requestAuthorization() }
            }
        }
    }

    private var liveEventsConnected: Bool {
        if case .connected = liveEventService.state {
            true
        } else {
            false
        }
    }

    private func copySanitizedDiagnostics() {
        let text = deviceStore.sanitizedDiagnostics(session: session, liveEventState: liveEventService.state.title)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        deviceStore.privacyActionMessage = "Copied sanitized diagnostics to the clipboard."
    }
}

import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    @Environment(LiveEventService.self) private var liveEventService

    @State private var tokenDraft = ""
    @State private var countryDraft: ThinQCountry = .US
    @State private var isTesting = false
    @State private var validation: TokenValidationState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            HStack(alignment: .top, spacing: 18) {
                stepCard(
                    number: "1",
                    title: "Create a ThinQ token",
                    text: "Use LG's Personal Access Token page with the same LG account that owns your devices."
                ) {
                    Button {
                        NSWorkspace.shared.open(APIReference.thinQPersonalAccessTokenPortal)
                    } label: {
                        Label("Open Token Page", systemImage: "safari")
                    }
                }

                stepCard(
                    number: "2",
                    title: "Paste it here",
                    text: "iThinkQ stores the token in macOS Keychain and uses it only for ThinQ API requests."
                ) {
                    SecureField("Personal Access Token", text: $tokenDraft)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Picker("Country", selection: $countryDraft) {
                    ForEach(ThinQCountry.allCases) { country in
                        Text(country.rawValue).tag(country)
                    }
                }
                Text("Region: \(countryDraft.region.rawValue.uppercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        Task { await testToken() }
                    } label: {
                        Label(isTesting ? "Testing..." : "Test Token", systemImage: "checkmark.shield")
                    }
                    .disabled(trimmedToken.isEmpty || isTesting)

                    Button {
                        Task { await saveAndContinue() }
                    } label: {
                        Label("Set Up iThinkQ", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedToken.isEmpty || isTesting)

                    Spacer()

                    Button("Use Sample Mode") {
                        session.completeOnboarding()
                        dismiss()
                    }
                }

                validationMessage
            }
        }
        .padding(28)
        .frame(width: 720)
        .onAppear {
            tokenDraft = session.personalAccessToken
            countryDraft = session.country
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 64, height: 64)
                .thinkQGlassSurface()

            VStack(alignment: .leading, spacing: 5) {
                Text("Set Up iThinkQ")
                    .font(.largeTitle.bold())
                Text("Connect your LG ThinQ account with a Personal Access Token.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepCard<Content: View>(
        number: String,
        title: String,
        text: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(number)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.cyan, in: Circle())
                Text(title)
                    .font(.headline)
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .thinkQGlassSurface()
    }

    @ViewBuilder
    private var validationMessage: some View {
        switch validation {
        case .idle:
            Text("Testing checks that LG accepts this token and can return your device list.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success(let count):
            Label("Token works. Found \(count) device\(count == 1 ? "" : "s").", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var trimmedToken: String {
        tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func testToken() async {
        isTesting = true
        validation = .idle
        defer { isTesting = false }

        do {
            let count = try await validateToken()
            validation = .success(deviceCount: count)
        } catch {
            validation = .failure(error.localizedDescription)
        }
    }

    private func saveAndContinue() async {
        isTesting = true
        defer { isTesting = false }

        do {
            let count = try await validateToken()
            validation = .success(deviceCount: count)
            session.country = countryDraft
            session.saveToken(trimmedToken)
            session.completeOnboarding()
            await deviceStore.refresh(session: session)
            await liveEventService.autoConnect(session: session, devices: deviceStore.devices) { message in
                deviceStore.applyLiveEvent(message)
            }
            dismiss()
        } catch {
            validation = .failure(error.localizedDescription)
        }
    }

    private func validateToken() async throws -> Int {
        let client = ThinQHTTPClient()
        let snapshot = ThinQSessionSnapshot(token: trimmedToken, country: countryDraft, clientID: session.clientID)
        return try await client.fetchDevices(session: snapshot).count
    }
}

private enum TokenValidationState: Equatable {
    case idle
    case success(deviceCount: Int)
    case failure(String)
}

import SwiftUI

struct ContentView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    @Environment(LiveEventService.self) private var liveEventService
    @State private var showingOnboarding = false

    var body: some View {
        @Bindable var store = deviceStore
        NavigationSplitView {
            SidebarView(selection: $store.selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            if let device = deviceStore.selectedDevice() {
                DeviceDetailView(device: device)
            } else {
                EmptyDeviceView()
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Find devices")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await deviceStore.refresh(session: session) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .onChange(of: liveEventKey) { _, _ in
            if let message = liveEventService.recentMessages.first {
                deviceStore.applyLiveEvent(message)
            }
        }
        .onChange(of: deviceListKey) { _, _ in
            Task {
                await liveEventService.autoConnect(session: session, devices: deviceStore.devices) { message in
                    deviceStore.applyLiveEvent(message)
                }
            }
        }
        .onAppear {
            showingOnboarding = shouldShowOnboarding
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environment(session)
                .environment(deviceStore)
                .environment(liveEventService)
        }
    }

    private var liveEventKey: UUID? {
        liveEventService.recentMessages.first?.id
    }

    private var deviceListKey: String {
        deviceStore.devices.map(\.id).sorted().joined(separator: "|")
    }

    private var shouldShowOnboarding: Bool {
        !session.hasToken && !session.onboardingCompleted
    }
}

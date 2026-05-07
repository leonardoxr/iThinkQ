import SwiftUI

struct StatusInspectorView: View {
    let status: DeviceStatus?
    let profile: DeviceProfile?
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Readings")
                            .font(.headline)
                        ForEach(statusRows, id: \.0) { key, value in
                            HStack(alignment: .firstTextBaseline) {
                                Text(key.thinkQHumanizedIdentifier)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(value.displayText.thinkQTitleCasedValue)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .thinkQGlassSurface()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Signals")
                            .font(.headline)
                        ForEach((profile?.capabilities ?? []).prefix(8)) { capability in
                            Label(capability.displayName, systemImage: capability.isWritable ? "slider.horizontal.3" : "eye")
                                .foregroundStyle(capability.isWritable ? .primary : .secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .thinkQGlassSurface()
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Advanced Status", systemImage: "list.bullet.rectangle")
                .font(.title2.bold())
        }
    }

    private var statusRows: [(String, ThinQJSON)] {
        Array((status?.values ?? [:]).sorted(by: { $0.key < $1.key }).prefix(8))
    }
}

struct EmptyDeviceView: View {
    var body: some View {
        ContentUnavailableView("No Device Selected", systemImage: "app.connected.to.app.below.fill", description: Text("Choose a ThinQ device from the sidebar."))
    }
}

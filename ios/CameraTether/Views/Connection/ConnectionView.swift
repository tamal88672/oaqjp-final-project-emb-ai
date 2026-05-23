import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var connectionVM: ConnectionViewModel
    @EnvironmentObject var discovery: PTPIPDiscovery
    @State private var selectedType: ConnectionType = .wifi

    var body: some View {
        VStack(spacing: 0) {
            // Status banner
            ConnectionStatusBadge(state: connectionVM.connectionState)
                .padding()

            Picker("Connection Type", selection: $selectedType) {
                Text("WiFi").tag(ConnectionType.wifi)
                Text("USB").tag(ConnectionType.usb)
                Text("iPhone").tag(ConnectionType.builtIn)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider().padding(.top, 8)

            switch selectedType {
            case .wifi:
                WiFiSetupView()
            case .usb:
                USBSetupView()
            case .builtIn:
                BuiltInCameraSetupView()
            }
        }
        .navigationTitle("Camera")
        .navigationBarItems(
            trailing: connectionVM.connectionState.isConnected
                ? Button("Disconnect") { Task { await connectionVM.disconnect() } }
                    .foregroundColor(.red)
                : nil
        )
        .onAppear { connectionVM.startDiscovery() }
        .onDisappear { connectionVM.stopDiscovery() }
    }
}

struct ConnectionStatusBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(state.statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var statusColor: Color {
        switch state {
        case .connected:     return .green
        case .connecting, .discovering, .reconnecting: return .yellow
        case .error:         return .red
        default:             return .gray
        }
    }
}

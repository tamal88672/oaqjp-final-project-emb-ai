import SwiftUI

struct WiFiSetupView: View {
    @EnvironmentObject var connectionVM: ConnectionViewModel
    @EnvironmentObject var discovery: PTPIPDiscovery
    @State private var manualIP: String = ""
    @State private var showManualEntry = false

    var body: some View {
        List {
            Section("Discovered Cameras") {
                if discovery.discoveredCameras.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Searching on local network…").foregroundColor(.secondary)
                    }
                } else {
                    ForEach(discovery.discoveredCameras) { camera in
                        DiscoveredCameraRow(camera: camera) {
                            Task { await connectionVM.connect(to: camera) }
                        }
                    }
                }
            }

            Section("Manual Connection") {
                HStack {
                    Image(systemName: "network")
                    TextField("Camera IP address", text: $connectionVM.manualIPAddress)
                        .keyboardType(.decimalPad)
                    Button("Connect") {
                        Task { await connectionVM.connectManual(ip: connectionVM.manualIPAddress) }
                    }
                    .disabled(connectionVM.manualIPAddress.isEmpty)
                }
            }

            Section("Setup Guide") {
                DisclosureGroup("Canon cameras") {
                    Text("Menu → Network Settings → WiFi Settings → EOS Utility → Pair. Enable 'Remote Shooting + Transfer'.")
                        .font(.caption).foregroundColor(.secondary)
                }
                DisclosureGroup("Nikon cameras") {
                    Text("Menu → Network → Connect to Smart Device. Select 'PC' mode. Note the IP address shown on screen.")
                        .font(.caption).foregroundColor(.secondary)
                }
                DisclosureGroup("Sony cameras") {
                    Text("Menu → Network → Send to Smartphone. OR use PlayMemories Remote to pair.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DiscoveredCameraRow: View {
    let camera: DiscoveredCamera
    let onConnect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "camera.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(camera.name).fontWeight(.medium)
                Text("\(camera.vendor.displayName) · \(camera.host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Connect", action: onConnect)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }
}

struct BuiltInCameraSetupView: View {
    @EnvironmentObject var connectionVM: ConnectionViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone").font(.system(size: 60)).foregroundColor(.accentColor)
            Text("Use iPhone Camera").font(.title2.bold())
            Text("Capture photos directly with the iPhone's built-in camera. Auto-edit applies immediately after each shot.")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("Use iPhone Camera") { connectionVM.selectBuiltInCamera() }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

struct USBSetupView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cable.connector").font(.system(size: 60)).foregroundColor(.secondary)
            Text("USB Tethering").font(.title2.bold())
            Text("Connect your camera with a USB cable and a Lightning/USB-C adapter.\n\nSupported: Canon (com.canon.eos.connect), Nikon (com.nikon.eac-d), Sony.\n\nNote: Requires Apple MFi entitlement from Apple.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.body)
        }
        .padding(40)
    }
}

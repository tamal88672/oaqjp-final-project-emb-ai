import SwiftUI

@main
struct CameraTetherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var connectionVM = ConnectionViewModel()
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var editVM = EditViewModel()
    @StateObject private var maskingVM = MaskingViewModel()
    @StateObject private var coordinator = PhotoTransferCoordinator()
    @StateObject private var discovery = PTPIPDiscovery()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(connectionVM)
                .environmentObject(libraryVM)
                .environmentObject(editVM)
                .environmentObject(maskingVM)
                .environmentObject(coordinator)
                .environmentObject(discovery)
                .onAppear {
                    connectionVM.discovery = discovery
                    connectionVM.coordinator = coordinator
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                discovery.startBrowsing()
            } else if phase == .background {
                discovery.stopBrowsing()
            }
        }
    }
}

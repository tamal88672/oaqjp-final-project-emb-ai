import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var connectionVM: ConnectionViewModel

    var body: some View {
        TabView {
            NavigationView { LibraryView() }
                .tabItem { Label("Library", systemImage: "photo.on.rectangle") }

            NavigationView { EditView() }
                .tabItem { Label("Edit", systemImage: "slider.horizontal.3") }

            NavigationView { ConnectionView() }
                .tabItem {
                    Label("Camera",
                          systemImage: connectionVM.connectionState.isConnected
                            ? "camera.fill"
                            : "camera")
                }
        }
    }
}

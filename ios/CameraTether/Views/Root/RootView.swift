import SwiftUI

struct RootView: View {
    @EnvironmentObject var coordinator: PhotoTransferCoordinator
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var editVM: EditViewModel
    @State private var showConnection = true

    var body: some View {
        ZStack {
            TabBarView()
                .sheet(isPresented: $showConnection) {
                    NavigationView { ConnectionView() }
                }
        }
        .onChange(of: coordinator.incomingPhoto) { photo in
            guard let photo else { return }
            libraryVM.addPhoto(photo)
            libraryVM.selectedPhoto = photo
            Task { await editVM.loadPhoto(photo) }
            showConnection = false
        }
    }
}

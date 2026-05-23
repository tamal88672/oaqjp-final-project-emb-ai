import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var editVM: EditViewModel
    @EnvironmentObject var coordinator: PhotoTransferCoordinator

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 2)], spacing: 2) {
                    ForEach(libraryVM.photos) { photo in
                        PhotoThumbnailView(photo: photo, isSelected: libraryVM.selectedPhoto?.id == photo.id)
                            .onTapGesture {
                                libraryVM.selectedPhoto = photo
                                Task { await editVM.loadPhoto(photo) }
                            }
                    }
                }
                .padding(.bottom, 80)
            }

            if coordinator.isTransferring {
                TransferProgressBanner(progress: coordinator.transferProgress)
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("Library")
        .navigationBarItems(trailing: sortMenu)
        .animation(.easeInOut(duration: 0.2), value: coordinator.isTransferring)
    }

    private var sortMenu: some View {
        Menu {
            Button("Newest First") { libraryVM.sortOrder = .dateDescending }
            Button("Oldest First") { libraryVM.sortOrder = .dateAscending }
            Divider()
            Button("All Sources") { libraryVM.filterSource = nil }
            Button("WiFi Only")   { libraryVM.filterSource = .wifi }
            Button("USB Only")    { libraryVM.filterSource = .usb }
            Button("iPhone Only") { libraryVM.filterSource = .builtIn }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: CapturedPhoto
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = photo.editedImageData ?? Optional(photo.rawData),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 110, height: 110)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: 110, height: 110)
            }

            HStack(spacing: 2) {
                Image(systemName: sourceIcon)
                    .font(.caption2)
            }
            .padding(4)
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(4)
            .padding(4)
        }
        .frame(width: 110, height: 110)
        .clipped()
    }

    private var sourceIcon: String {
        switch photo.source {
        case .wifi:    return "wifi"
        case .usb:     return "cable.connector"
        case .builtIn: return "iphone"
        }
    }
}

struct TransferProgressBanner: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
            Text("Transferring… \(Int(progress * 100))%")
                .font(.caption)
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
        .padding()
    }
}

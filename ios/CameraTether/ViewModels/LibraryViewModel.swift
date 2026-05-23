import Foundation
import UIKit

enum SortOrder { case dateAscending, dateDescending }

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var photos: [CapturedPhoto] = []
    @Published var selectedPhoto: CapturedPhoto?
    @Published var sortOrder: SortOrder = .dateDescending
    @Published var filterSource: PhotoSource? = nil
    @Published var isExporting: Bool = false

    private var allPhotos: [CapturedPhoto] = []

    func addPhoto(_ photo: CapturedPhoto) {
        allPhotos.append(photo)
        applyFiltersAndSort()
    }

    func deletePhoto(_ photo: CapturedPhoto) {
        allPhotos.removeAll { $0.id == photo.id }
        if selectedPhoto?.id == photo.id { selectedPhoto = nil }
        applyFiltersAndSort()
    }

    func exportPhoto(_ photo: CapturedPhoto) async {
        isExporting = true
        defer { isExporting = false }
        let data = photo.editedImageData ?? photo.rawData
        try? await PhotoLibraryService.shared.saveDataToLibrary(data)
    }

    func updatePhoto(_ photo: CapturedPhoto) {
        if let idx = allPhotos.firstIndex(where: { $0.id == photo.id }) {
            allPhotos[idx] = photo
        } else {
            allPhotos.append(photo)
        }
        if selectedPhoto?.id == photo.id { selectedPhoto = photo }
        applyFiltersAndSort()
    }

    private func applyFiltersAndSort() {
        var result = filterSource == nil
            ? allPhotos
            : allPhotos.filter { $0.source == filterSource }
        result.sort { a, b in
            sortOrder == .dateDescending
                ? a.captureDate > b.captureDate
                : a.captureDate < b.captureDate
        }
        photos = result
    }
}

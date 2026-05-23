import Foundation
import Photos
import UIKit

final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    @discardableResult
    func saveToLibrary(_ image: UIImage) async throws -> String {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "PhotoLibrary", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"])
        }
        var localID: String = ""
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetChangeRequest.creationRequestForAsset(from: image)
            localID = req.placeholderForCreatedAsset?.localIdentifier ?? ""
        }
        return localID
    }

    func saveDataToLibrary(_ data: Data) async throws -> String {
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "PhotoLibrary", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        return try await saveToLibrary(image)
    }
}

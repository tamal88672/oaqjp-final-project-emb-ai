import Foundation

protocol CameraSource: Actor {
    var connectionState: ConnectionState { get }
    var newPhotoStream: AsyncStream<CapturedPhoto> { get }

    func connect() async throws
    func disconnect() async throws
    func fetchLatestPhotos(limit: Int) async throws -> [CapturedPhoto]
}

import Foundation
import UIKit

@MainActor
final class PhotoTransferCoordinator: ObservableObject {
    @Published private(set) var incomingPhoto: CapturedPhoto?
    @Published private(set) var transferProgress: Double = 0
    @Published private(set) var isTransferring: Bool = false

    private var currentSource: (any CameraSource)?
    private let transferQueue = TransferQueue()
    private var listenTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func attach(source: any CameraSource) {
        detach()
        currentSource = source

        listenTask = Task {
            for await photo in await source.newPhotoStream {
                await transferQueue.enqueue(photo)
            }
        }

        processTask = Task {
            while !Task.isCancelled {
                let photo = await transferQueue.dequeue()
                await processIncoming(photo)
            }
        }
    }

    func detach() {
        listenTask?.cancel()
        processTask?.cancel()
        listenTask = nil
        processTask = nil
        currentSource = nil
        endBackgroundTask()
    }

    private func processIncoming(_ photo: CapturedPhoto) async {
        beginBackgroundTask()
        isTransferring = true
        transferProgress = 0

        var processed = photo
        // Auto-edit runs on background actor, result comes back here
        let edited = await Task.detached(priority: .userInitiated) {
            await AutoEditEngine.shared.process(photo: photo, preset: .none)
        }.value

        transferProgress = 0.8

        if let edited {
            var jpeg: Data?
            let context = CIContext()
            if let cg = context.createCGImage(edited, from: edited.extent) {
                jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.92)
            }
            processed.editedImageData = jpeg
        }

        transferProgress = 1.0
        incomingPhoto = processed
        isTransferring = false
        endBackgroundTask()
    }

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CameraTransfer") {
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

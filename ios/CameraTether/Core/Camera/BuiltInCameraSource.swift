import Foundation
import AVFoundation
import UIKit

actor BuiltInCameraSource: NSObject, CameraSource {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private(set) var connectionState: ConnectionState = .disconnected
    private var photoContinuation: AsyncStream<CapturedPhoto>.Continuation?

    private(set) lazy var newPhotoStream: AsyncStream<CapturedPhoto> = AsyncStream { [weak self] cont in
        Task { await self?.setContinuation(cont) }
    }

    func connect() async throws {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        guard status else {
            throw NSError(domain: "CameraTether", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Camera access denied"])
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw NSError(domain: "CameraTether", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create camera input"])
        }
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }
        captureSession.commitConfiguration()
        captureSession.startRunning()

        let builtInDevice = CameraDevice.builtIn()
        connectionState = .connected(device: builtInDevice)
    }

    func disconnect() async throws {
        captureSession.stopRunning()
        connectionState = .disconnected
        photoContinuation?.finish()
    }

    func fetchLatestPhotos(limit: Int) async throws -> [CapturedPhoto] { [] }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func setContinuation(_ cont: AsyncStream<CapturedPhoto>.Continuation) {
        photoContinuation = cont
    }
}

extension BuiltInCameraSource: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        let captured = CapturedPhoto(
            rawData: data,
            filename: "IMG_\(Int(Date().timeIntervalSince1970)).jpg",
            source: .builtIn,
            format: .jpeg
        )
        Task { await yieldPhoto(captured) }
    }

    private func yieldPhoto(_ photo: CapturedPhoto) {
        photoContinuation?.yield(photo)
    }
}

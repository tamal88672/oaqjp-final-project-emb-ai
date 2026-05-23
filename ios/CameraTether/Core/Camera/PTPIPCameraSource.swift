import Foundation

actor PTPIPCameraSource: CameraSource {
    private let session: PTPIPSession
    private let device: CameraDevice
    private(set) var connectionState: ConnectionState = .disconnected
    private var photoContinuation: AsyncStream<CapturedPhoto>.Continuation?

    private(set) lazy var newPhotoStream: AsyncStream<CapturedPhoto> = AsyncStream { [weak self] cont in
        Task { await self?.setContinuation(cont) }
    }

    init(camera: DiscoveredCamera) {
        self.session = PTPIPSession(host: camera.host, port: camera.port)
        self.device = camera.toCameraDevice()
    }

    func connect() async throws {
        connectionState = .connecting(host: device.hostAddress ?? "")
        do {
            try await withRetry(maxAttempts: 4) { [weak self] in
                try await self?.session.open()
            }
            connectionState = .connected(device: device)
            Task { await listenForNewPhotos() }
        } catch {
            connectionState = .error(message: error.localizedDescription)
            throw error
        }
    }

    func disconnect() async throws {
        try await session.close()
        connectionState = .disconnected
        photoContinuation?.finish()
    }

    func fetchLatestPhotos(limit: Int) async throws -> [CapturedPhoto] {
        let handles = try await session.listObjectHandles()
        let recent = Array(handles.suffix(limit))
        var photos: [CapturedPhoto] = []
        for handle in recent {
            if let photo = try? await fetchPhoto(handle: handle) {
                photos.append(photo)
            }
        }
        return photos
    }

    // MARK: - Private

    private func setContinuation(_ cont: AsyncStream<CapturedPhoto>.Continuation) {
        photoContinuation = cont
    }

    private func listenForNewPhotos() async {
        for await handle in session.newObjectStream {
            if let photo = try? await fetchPhoto(handle: handle) {
                photoContinuation?.yield(photo)
            }
        }
    }

    private func fetchPhoto(handle: UInt32) async throws -> CapturedPhoto {
        let (info, data) = try await session.fetchObject(handle: handle)
        let format = ImageFormat.from(filename: info.filename)
        return CapturedPhoto(
            rawData: data,
            filename: info.filename,
            captureDate: info.captureDate ?? Date(),
            source: .wifi,
            format: format
        )
    }
}

// MARK: - Retry helper

private func withRetry<T>(maxAttempts: Int, operation: @escaping () async throws -> T) async throws -> T {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
            try? await Task.sleep(nanoseconds: delay)
        }
    }
    throw lastError!
}

import Foundation

actor TransferQueue {
    private var queue: [CapturedPhoto] = []
    private let maxCapacity = 10
    private var waiters: [CheckedContinuation<CapturedPhoto, Never>] = []
    private var producerWaiters: [CheckedContinuation<Void, Never>] = []

    var count: Int { queue.count }

    func enqueue(_ photo: CapturedPhoto) async {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: photo)
            return
        }
        if queue.count >= maxCapacity {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                producerWaiters.append(cont)
            }
        }
        queue.append(photo)
    }

    func dequeue() async -> CapturedPhoto {
        if let photo = queue.first {
            queue.removeFirst()
            if let waiter = producerWaiters.first {
                producerWaiters.removeFirst()
                waiter.resume()
            }
            return photo
        }
        return await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }
}

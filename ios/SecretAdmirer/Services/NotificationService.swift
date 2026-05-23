import Foundation
import UserNotifications

final class NotificationService: NSObject {
    private let api: APIClient
    init(api: APIClient) { self.api = api }

    func list() async throws -> [AppNotification] {
        try await api.request(.get, "/notifications")
    }

    func markRead(_ id: UUID) async throws {
        _ = try await api.request(.post, "/notifications/\(id.uuidString.lowercased())/read", as: EmptyResponse.self)
    }

    func registerDevice(token: String, platform: String = "apns") async throws {
        struct Req: Encodable { let platform: String; let token: String }
        _ = try await api.request(.post, "/notifications/devices",
            body: Req(platform: platform, token: token),
            as: EmptyResponse.self)
    }

    /// Request push permission and register the resulting APNs token. Returns
    /// true if the user granted permission.
    func requestPushPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }
}

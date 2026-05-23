import Foundation

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userId: UUID
    let handle: String
}

struct UserProfile: Codable, Identifiable {
    let userId: UUID
    let handle: String
    var displayName: String?
    var bio: String?
    var avatarUrl: String?
    var theme: String
    var allowReplies: Bool

    var id: UUID { userId }
}

struct PublicProfile: Codable {
    let handle: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let allowReplies: Bool
}

struct Message: Codable, Identifiable, Hashable {
    let id: UUID
    let body: String
    let receivedAt: Date
    let read: Bool
}

struct InboxPage: Codable {
    let items: [Message]
    let nextCursor: String?
    let unreadCount: Int
    let totalCount: Int
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let type: String
    let messageId: UUID?
    let title: String
    let body: String?
    let createdAt: Date
    let readAt: Date?
}

struct AuthSession: Codable, Identifiable, Hashable {
    let id: UUID
    let device: String?
    let ip: String?
    let lastSeen: Date
    let issuedAt: Date
}

struct ShareLink: Codable {
    let url: String
}

struct APIError: LocalizedError, Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
    }
    let error: Body

    var code: String { error.code }
    var errorDescription: String? { error.message }
}

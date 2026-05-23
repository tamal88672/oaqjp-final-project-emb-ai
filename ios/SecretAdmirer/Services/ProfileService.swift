import Foundation

final class ProfileService {
    private let api: APIClient
    init(api: APIClient) { self.api = api }

    func me() async throws -> UserProfile {
        try await api.request(.get, "/profile/me")
    }

    func byHandle(_ handle: String) async throws -> PublicProfile {
        try await api.request(.get, "/profile/by-handle/\(handle.lowercased())", authenticated: false)
    }

    func patch(displayName: String?, bio: String?, theme: String?, allowReplies: Bool?) async throws -> UserProfile {
        struct Req: Encodable {
            let displayName: String?
            let bio: String?
            let theme: String?
            let allowReplies: Bool?
        }
        return try await api.request(.patch, "/profile",
            body: Req(displayName: displayName, bio: bio, theme: theme, allowReplies: allowReplies))
    }

    func uploadAvatar(data: Data, mimeType: String) async throws -> String {
        let ext: String
        switch mimeType {
        case "image/jpeg": ext = "jpg"
        case "image/png":  ext = "png"
        default:           ext = "img"
        }
        let body = MultipartBody.file(field: "avatar", filename: "avatar.\(ext)", mimeType: mimeType, data: data)
        let raw = try await api.requestRaw(.put, "/profile/avatar", multipart: body)
        struct Res: Decodable { let avatarUrl: String }
        let res = try JSONDecoder().decode(Res.self, from: raw)
        return res.avatarUrl
    }

    func shareLink() async throws -> URL {
        let link: ShareLink = try await api.request(.get, "/profile/link")
        return URL(string: link.url) ?? URL(string: "about:blank")!
    }

    func sessions() async throws -> [AuthSession] {
        try await api.request(.get, "/auth/sessions")
    }

    func revoke(session id: UUID) async throws {
        _ = try await api.request(.delete, "/auth/sessions/\(id.uuidString.lowercased())", as: EmptyResponse.self)
    }
}

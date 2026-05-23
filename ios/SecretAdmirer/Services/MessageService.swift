import Foundation

final class MessageService {
    private let api: APIClient
    init(api: APIClient) { self.api = api }

    func inbox(cursor: String? = nil, limit: Int = 30) async throws -> InboxPage {
        var path = "/messages/inbox?limit=\(limit)"
        if let cursor = cursor, !cursor.isEmpty {
            path += "&cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }
        return try await api.request(.get, path)
    }

    func read(_ id: UUID) async throws -> Message {
        try await api.request(.get, "/messages/\(id.uuidString.lowercased())")
    }

    func delete(_ id: UUID) async throws {
        _ = try await api.request(.delete, "/messages/\(id.uuidString.lowercased())", as: EmptyResponse.self)
    }

    func send(to handle: String, body: String) async throws {
        struct Req: Encodable { let receiverHandle: String; let body: String }
        struct Res: Decodable { let messageId: UUID; let status: String }
        _ = try await api.request(.post, "/messages",
            body: Req(receiverHandle: handle, body: body),
            authenticated: false,
            as: Res.self)
    }
}

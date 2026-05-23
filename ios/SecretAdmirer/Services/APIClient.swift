import Foundation

enum HTTPMethod: String { case get = "GET", post = "POST", patch = "PATCH", put = "PUT", delete = "DELETE" }

/// Thin URLSession wrapper. Handles bearer-token attachment, JSON encoding,
/// and a single transparent refresh on 401. Refresh races are coalesced —
/// concurrent 401s won't fire multiple `/auth/refresh` calls.
final class APIClient {
    let baseURL: URL
    let tokens: TokenStore
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var refreshHandler: (() async throws -> Void)?
    private var refreshTask: Task<Void, Error>?

    init(baseURL: URL, tokens: TokenStore) {
        self.baseURL = baseURL
        self.tokens = tokens
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: cfg)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractional
        decoder.keyDecodingStrategy = .useDefaultKeys

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .useDefaultKeys
    }

    @discardableResult
    func request<T: Decodable>(
        _ method: HTTPMethod,
        _ path: String,
        body: Encodable? = nil,
        authenticated: Bool = true,
        as _: T.Type = T.self
    ) async throws -> T {
        let (data, response) = try await send(method, path, body: body, authenticated: authenticated)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if 200..<300 ~= http.statusCode {
            if T.self == EmptyResponse.self { return EmptyResponse() as! T }
            return try decoder.decode(T.self, from: data)
        }
        if let apiErr = try? decoder.decode(APIError.self, from: data) { throw apiErr }
        throw URLError(URLError.Code(rawValue: http.statusCode))
    }

    func requestRaw(_ method: HTTPMethod, _ path: String, multipart: MultipartBody, authenticated: Bool = true) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method.rawValue
        req.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        if authenticated, let token = tokens.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = multipart.body
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401, authenticated, let refresh = refreshHandler {
            try await coalesce(refresh)
            return try await requestRaw(method, path, multipart: multipart, authenticated: authenticated)
        }
        if !(200..<300 ~= http.statusCode) {
            if let apiErr = try? decoder.decode(APIError.self, from: data) { throw apiErr }
            throw URLError(URLError.Code(rawValue: http.statusCode))
        }
        return data
    }

    private func send(_ method: HTTPMethod, _ path: String, body: Encodable?, authenticated: Bool) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = tokens.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 401, authenticated, let refresh = refreshHandler {
            try await coalesce(refresh)
            return try await send(method, path, body: body, authenticated: authenticated)
        }
        return (data, response)
    }

    private func coalesce(_ refresh: @escaping () async throws -> Void) async throws {
        if let existing = refreshTask {
            try await existing.value
            return
        }
        let task = Task { try await refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }
}

struct EmptyResponse: Decodable {}

struct AnyEncodable: Encodable {
    let wrapped: Encodable
    init(_ wrapped: Encodable) { self.wrapped = wrapped }
    func encode(to encoder: Encoder) throws { try wrapped.encode(to: encoder) }
}

struct MultipartBody {
    let boundary: String
    let body: Data

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    static func file(field: String, filename: String, mimeType: String, data: Data) -> MultipartBody {
        let boundary = "----SecretAdmirer-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return MultipartBody(boundary: boundary, body: body)
    }
}

extension JSONDecoder.DateDecodingStrategy {
    /// ISO8601 with or without fractional seconds — the C# API emits both.
    static var iso8601withFractional: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f1.date(from: str) { return d }
            let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
            if let d = f2.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO date: \(str)")
        }
    }
}

import Foundation

@MainActor
final class AuthService: ObservableObject {
    enum State: Equatable { case checking, signedOut, signedIn(handle: String, userId: UUID) }

    @Published private(set) var state: State = .checking

    private let api: APIClient
    private let tokens: TokenStore

    init(api: APIClient, tokens: TokenStore) {
        self.api = api
        self.tokens = tokens
    }

    var currentUserHandle: String? {
        if case let .signedIn(handle, _) = state { return handle } else { return nil }
    }

    func restoreSession() async {
        if tokens.accessToken == nil && tokens.refreshToken == nil {
            state = .signedOut
            return
        }
        // Try to fetch /auth/me — if it fails, refresh; if refresh fails, sign out.
        do {
            let me: MeResponse = try await api.request(.get, "/auth/me")
            state = .signedIn(handle: me.handle, userId: me.id)
        } catch {
            state = .signedOut
            tokens.clear()
        }
    }

    func login(identifier: String, password: String) async throws {
        let pair: TokenPair = try await api.request(.post, "/auth/login",
            body: LoginRequest(identifier: identifier, password: password),
            authenticated: false)
        persist(pair)
    }

    func register(handle: String, email: String, password: String) async throws {
        let pair: TokenPair = try await api.request(.post, "/auth/register",
            body: RegisterRequest(handle: handle, email: email, password: password),
            authenticated: false)
        persist(pair)
    }

    func refresh() async throws {
        guard let refresh = tokens.refreshToken else {
            await signOut(local: true); throw URLError(.userAuthenticationRequired)
        }
        do {
            let pair: TokenPair = try await api.request(.post, "/auth/refresh",
                body: RefreshRequest(refreshToken: refresh),
                authenticated: false)
            persist(pair)
        } catch {
            await signOut(local: true)
            throw error
        }
    }

    func signOut() async {
        if let refresh = tokens.refreshToken {
            _ = try? await api.request(.post, "/auth/logout",
                body: RefreshRequest(refreshToken: refresh),
                as: EmptyResponse.self)
        }
        await signOut(local: true)
    }

    private func signOut(local: Bool) async {
        tokens.clear()
        state = .signedOut
    }

    private func persist(_ pair: TokenPair) {
        tokens.accessToken = pair.accessToken
        tokens.refreshToken = pair.refreshToken
        state = .signedIn(handle: pair.handle, userId: pair.userId)
    }

    private struct LoginRequest: Encodable { let identifier: String; let password: String }
    private struct RegisterRequest: Encodable { let handle: String; let email: String; let password: String }
    private struct RefreshRequest: Encodable { let refreshToken: String }
    private struct MeResponse: Decodable { let id: UUID; let handle: String; let email: String }
}

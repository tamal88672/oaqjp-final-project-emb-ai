import SwiftUI

@main
struct SecretAdmirerApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.auth)
                .preferredColorScheme(.dark)
                .tint(Theme.crimsonRose)
                .background(Theme.velvetNight.ignoresSafeArea())
        }
    }
}

/// Composition root. Construct services once, hand them to view models via
/// the environment. This keeps the SwiftUI views free of singletons and
/// makes the test seam obvious — swap `AppContainer` to inject fakes.
final class AppContainer: ObservableObject {
    let config = Configuration.default
    let keychain: KeychainStore
    let api: APIClient
    let auth: AuthService
    let messages: MessageService
    let profiles: ProfileService
    let notifications: NotificationService

    init() {
        self.keychain = KeychainStore(service: "app.secretadmirer.tokens")
        let store = TokenStore(keychain: keychain)
        self.api = APIClient(baseURL: config.apiBaseURL, tokens: store)
        self.auth = AuthService(api: api, tokens: store)
        self.messages = MessageService(api: api)
        self.profiles = ProfileService(api: api)
        self.notifications = NotificationService(api: api)

        // Wire the API client's refresh callback so a 401 anywhere falls
        // back to AuthService.refresh rather than re-implementing rotation.
        api.refreshHandler = { [weak auth] in
            try await auth?.refresh()
        }
    }
}

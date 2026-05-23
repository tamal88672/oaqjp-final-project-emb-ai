import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            switch auth.state {
            case .signedOut:
                AuthGateView()
            case .signedIn:
                MainTabView()
            case .checking:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.champagne)
            }
        }
        .task { await auth.restoreSession() }
    }
}

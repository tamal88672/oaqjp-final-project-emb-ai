import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        TabView {
            InboxView()
                .tabItem { Label("Inbox", systemImage: "envelope.fill") }
            ShareLinkView()
                .tabItem { Label("Share", systemImage: "link") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Theme.champagne)
    }
}

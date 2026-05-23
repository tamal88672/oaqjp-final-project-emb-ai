import SwiftUI

struct ShareLinkView: View {
    @EnvironmentObject var container: AppContainer
    @State private var shareURL: URL?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.heroGradient.ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    Text("Share your link")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Anyone with this link can send you\nan anonymous note.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    if let url = shareURL {
                        Text(url.absoluteString)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Theme.champagne)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Theme.velvetNight.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 12)

                        HStack(spacing: 14) {
                            Button {
                                UIPasteboard.general.url = url
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: { Text(copied ? "Copied" : "Copy") }
                            .buttonStyle(GhostButtonStyle())

                            ShareLink(item: url) { Text("Share") }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.horizontal, 12)
                    } else {
                        ProgressView().tint(.white)
                    }
                    Spacer()
                }
                .padding(20)
            }
            .task {
                shareURL = try? await container.profiles.shareLink()
            }
        }
    }
}

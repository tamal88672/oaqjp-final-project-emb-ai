import SwiftUI

struct InboxView: View {
    @EnvironmentObject var container: AppContainer

    @State private var items: [Message] = []
    @State private var unreadCount = 0
    @State private var shareLink: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var nextCursor: String?
    @State private var selected: Message?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.velvetNight.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let link = shareLink { ShareCard(url: link) }

                        HStack {
                            Text("Notes")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Theme.whisper)
                            if unreadCount > 0 {
                                Text("· \(unreadCount) unread")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.champagne)
                            }
                        }

                        if isLoading && items.isEmpty {
                            ProgressView().tint(Theme.champagne)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else if items.isEmpty {
                            EmptyState()
                        } else {
                            ForEach(items) { msg in
                                Button { Task { await open(msg) } } label: {
                                    InboxRow(message: msg)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let msg = errorMessage {
                            Text(msg).foregroundStyle(.red).font(.footnote)
                        }
                    }
                    .padding(20)
                }
                .refreshable { await refresh() }
            }
            .navigationTitle("Inbox")
            .toolbarBackground(Theme.velvetNight, for: .navigationBar)
            .task { await refresh() }
            .sheet(item: $selected) { msg in
                MessageDetailView(message: msg) {
                    Task { await deleteMessage(msg); selected = nil }
                }
            }
        }
    }

    private func refresh() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            async let page = container.messages.inbox()
            async let link = container.profiles.shareLink()
            let (p, l) = try await (page, link)
            items = p.items
            unreadCount = p.unreadCount
            nextCursor = p.nextCursor
            shareLink = l
        } catch let api as APIError {
            errorMessage = api.errorDescription
        } catch {
            errorMessage = "Couldn't load your inbox."
        }
    }

    private func open(_ message: Message) async {
        do {
            let updated = try await container.messages.read(message.id)
            if let idx = items.firstIndex(of: message) {
                items[idx] = updated
                if !message.read { unreadCount = max(0, unreadCount - 1) }
            }
            selected = updated
        } catch {
            selected = message
        }
    }

    private func deleteMessage(_ message: Message) async {
        do {
            try await container.messages.delete(message.id)
            items.removeAll { $0.id == message.id }
            if !message.read { unreadCount = max(0, unreadCount - 1) }
        } catch let api as APIError {
            errorMessage = api.errorDescription
        } catch {
            errorMessage = "Could not delete."
        }
    }
}

private struct ShareCard: View {
    let url: URL
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Your link").font(.headline).foregroundStyle(Theme.whisper)
            Text(url.absoluteString)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Theme.champagne)
                .lineLimit(1).truncationMode(.middle)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.shadowInk)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.url = url
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: { Text(copied ? "Copied" : "Copy") }
                .buttonStyle(GhostButtonStyle())

                ShareLink(item: url) { Text("Share") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.roseGold, lineWidth: 1))
    }
}

private struct InboxRow: View {
    let message: Message
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.heroGradient)
                Text("?").font(.title3.weight(.bold)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(message.body)
                    .foregroundStyle(Theme.whisper)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(message.receivedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.dustyBlush)
            }
            Spacer()
            if !message.read {
                Circle().fill(Theme.champagne).frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .background(Theme.midnightPlum)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundStyle(Theme.roseGold)
            Text("No notes yet.").font(.headline).foregroundStyle(Theme.whisper)
            Text("Share your link to start receiving messages from your secret admirers.")
                .font(.subheadline)
                .foregroundStyle(Theme.dustyBlush)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var auth: AuthService

    @State private var profile: UserProfile?
    @State private var sessions: [AuthSession] = []
    @State private var displayName = ""
    @State private var bio = ""
    @State private var theme = "velvet"
    @State private var allowReplies = true
    @State private var isSaving = false
    @State private var savedAt: Date?
    @State private var errorMessage: String?
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.velvetNight.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        profileCard
                        sessionsCard
                        dangerCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .toolbarBackground(Theme.velvetNight, for: .navigationBar)
            .task { await load() }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.heroGradient)
                    .frame(width: 96, height: 96)
                if let url = profile?.avatarUrl, let u = URL(string: url) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            Text(SA_initial(profile?.displayName ?? profile?.handle ?? "?"))
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                } else {
                    Text(SA_initial(profile?.displayName ?? profile?.handle ?? "?"))
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: Theme.shadowInk.opacity(0.6), radius: 16, y: 4)

            PhotosPicker(selection: $avatarItem, matching: .images) {
                Text("Change photo").font(.subheadline.weight(.semibold))
            }
            .onChange(of: avatarItem) { item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                    let url = try? await container.profiles.uploadAvatar(data: data, mimeType: "image/jpeg")
                    if var p = profile, let url { p.avatarUrl = url; profile = p }
                }
            }

            Group {
                field("Handle", text: .constant(profile?.handle ?? ""), disabled: true)
                field("Display name", text: $displayName)
                VStack(alignment: .leading, spacing: 6) {
                    Text("BIO").font(.caption2.weight(.semibold)).foregroundStyle(Theme.dustyBlush)
                    TextEditor(text: $bio)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Theme.shadowInk.opacity(0.6))
                        .foregroundStyle(Theme.whisper)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.roseGold.opacity(0.3)))
                }
                Picker("Theme", selection: $theme) {
                    Text("Velvet").tag("velvet")
                    Text("Midnight").tag("midnight")
                    Text("Rose").tag("rose")
                    Text("Champagne").tag("champagne")
                }
                .pickerStyle(.segmented)
                Toggle("Accept new messages", isOn: $allowReplies)
                    .tint(Theme.crimsonRose)
                    .foregroundStyle(Theme.whisper)
            }

            if let msg = errorMessage {
                Text(msg).foregroundStyle(.red).font(.footnote)
            }
            if savedAt != nil {
                Text("Saved.").foregroundStyle(Theme.champagne).font(.footnote)
            }

            Button {
                Task { await save() }
            } label: {
                if isSaving { ProgressView().tint(.white) }
                else { Text("Save profile") }
            }
            .buttonStyle(PrimaryButtonStyle(disabled: isSaving))
            .disabled(isSaving)
        }
        .padding(20)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active sessions")
                .font(.headline)
                .foregroundStyle(Theme.whisper)
            Text("Each signed-in device gets a session you can revoke from here.")
                .font(.footnote)
                .foregroundStyle(Theme.dustyBlush)
            ForEach(sessions) { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.device ?? "Unknown device")
                            .foregroundStyle(Theme.whisper).lineLimit(1)
                        Text("Last seen \(s.lastSeen, format: .relative(presentation: .named))")
                            .font(.caption).foregroundStyle(Theme.dustyBlush)
                    }
                    Spacer()
                    Button("Revoke") { Task { await revoke(s.id) } }
                        .buttonStyle(GhostButtonStyle())
                        .frame(width: 80)
                }
                .padding(.vertical, 6)
                Divider().background(Theme.roseGold.opacity(0.2))
            }
        }
        .padding(20)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dangerCard: some View {
        VStack(spacing: 12) {
            Text("Danger zone").font(.headline).foregroundStyle(Theme.whisper)
            Button("Sign out") {
                Task { await auth.signOut() }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(20)
        .background(Theme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.dustyBlush)
            TextField("", text: text)
                .textFieldStyle(VelvetFieldStyle())
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
    }

    private func load() async {
        do {
            async let me = container.profiles.me()
            async let s = container.profiles.sessions()
            let (p, sess) = try await (me, s)
            profile = p
            displayName = p.displayName ?? ""
            bio = p.bio ?? ""
            theme = p.theme
            allowReplies = p.allowReplies
            sessions = sess
        } catch let api as APIError {
            errorMessage = api.errorDescription
        } catch {
            errorMessage = "Couldn't load profile."
        }
    }

    private func save() async {
        errorMessage = nil
        savedAt = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await container.profiles.patch(
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                theme: theme, allowReplies: allowReplies)
            profile = updated
            savedAt = Date()
        } catch let api as APIError {
            errorMessage = api.errorDescription
        } catch {
            errorMessage = "Could not save."
        }
    }

    private func revoke(_ id: UUID) async {
        do {
            try await container.profiles.revoke(session: id)
            sessions.removeAll { $0.id == id }
        } catch {}
    }

    private func SA_initial(_ s: String) -> String {
        String(s.prefix(1)).uppercased()
    }
}

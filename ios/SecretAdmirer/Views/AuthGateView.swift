import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var auth: AuthService

    enum Mode: String, CaseIterable { case signIn = "Sign in", register = "Create account" }
    @State private var mode: Mode = .signIn
    @State private var identifier = ""
    @State private var handle = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Theme.velvetNight.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
                    Hero()
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { m in Text(m.rawValue).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 16) {
                        if mode == .signIn {
                            field("Handle or email", text: $identifier, contentType: .username)
                            field("Password", text: $password, contentType: .password, secure: true)
                        } else {
                            field("Handle", text: $handle, contentType: .username,
                                  filter: { v in v.lowercased().filter { "abcdefghijklmnopqrstuvwxyz0123456789_".contains($0) } })
                            field("Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                            field("Password (8+ chars)", text: $password, contentType: .newPassword, secure: true)
                        }

                        if let msg = errorMessage {
                            Text(msg).foregroundStyle(.red).font(.footnote)
                        }

                        Button { Task { await submit() } } label: {
                            if isWorking { ProgressView().tint(.white) }
                            else { Text(mode == .signIn ? "Sign in" : "Create account") }
                        }
                        .buttonStyle(PrimaryButtonStyle(disabled: isWorking))
                        .disabled(isWorking || !canSubmit)
                    }
                    .padding(20)
                    .background(Theme.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Text("No fake notifications. Real login. Editable profile.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dustyBlush)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .signIn: return !identifier.isEmpty && !password.isEmpty
        case .register: return !handle.isEmpty && !email.isEmpty && password.count >= 8
        }
    }

    private func submit() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            switch mode {
            case .signIn:
                try await auth.login(identifier: identifier.trimmingCharacters(in: .whitespaces),
                                     password: password)
            case .register:
                try await auth.register(handle: handle, email: email, password: password)
            }
        } catch let api as APIError {
            errorMessage = api.errorDescription
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>,
                       contentType: UITextContentType? = nil,
                       keyboard: UIKeyboardType = .default,
                       secure: Bool = false,
                       filter: ((String) -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.dustyBlush)
            Group {
                if secure { SecureField("", text: text) }
                else      { TextField("", text: text).keyboardType(keyboard) }
            }
            .textContentType(contentType)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .textFieldStyle(VelvetFieldStyle())
            .onChange(of: text.wrappedValue) { newValue in
                if let filter, filter(newValue) != newValue {
                    text.wrappedValue = filter(newValue)
                }
            }
        }
    }
}

private struct Hero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From your\nsecret admirer.")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text("Share a link. Receive anonymous notes\nfrom the people who notice you.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.shadowInk.opacity(0.7), radius: 20, y: 8)
    }
}

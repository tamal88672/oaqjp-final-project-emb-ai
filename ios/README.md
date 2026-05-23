# Secret Admirer — iOS

SwiftUI client for iOS 16+. MVVM, URLSession, Keychain-backed token storage.

## Running

1. Open `SecretAdmirer/` in Xcode 15 (File → Open → select this folder).
   If you'd rather start fresh, run `swift package init --type executable`
   inside `SecretAdmirer/` and add the files manually — Xcode project files
   are deliberately not checked in.
2. Edit `App/Configuration.swift` to point `apiBaseURL` at your local gateway
   (default `http://localhost:8080`).
3. Build & run on the iOS 16 simulator.

## Layout

```
SecretAdmirer/
  App/                 # entry point + DI container + configuration
  Theme/               # color tokens (matches docs/color-palette.md)
  Models/              # plain DTOs
  Services/            # APIClient, AuthService, MessageService, Keychain
  ViewModels/          # one per screen, ObservableObject
  Views/               # SwiftUI screens
  Resources/           # Info.plist additions, app icon spec
```

## Design notes

- Tokens live in the Keychain (`KeychainStore`), never in `UserDefaults`.
- The API client transparently refreshes the access token once on 401, then
  retries the request. Concurrent 401s are coalesced.
- Notifications only display when an `APNs` push arrives carrying a real
  `messageId`. The app does not poll-and-fake.

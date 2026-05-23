# Secret Admirer

An anonymous-message app inspired by NGL but rebuilt for stability and trust.
Receivers share a link; admirers send anonymous messages. The brand reads
"this is from your secret admirer" — a velvet, crimson, and rose-gold palette
instead of NGL's hot-pink/orange.

This repository ships both targets:

- `ios/` — native SwiftUI client (iOS 16+)
- `web/` — C# microservices backend (ASP.NET Core 8) + jQuery / vanilla JS
  frontend, SQL persistence, SAGA orchestration, and an in-process pub/sub bus
  with a pluggable transport.

## Why rebuild NGL

The App Store reviews for NGL are dominated by three complaints. We address
each at the architecture level:

| NGL complaint                       | Our fix                                                                                                          |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| "Fake notifications from friends"   | The `NotificationService` only emits push/email when a *real* `MessageReceived` event is published on the bus. There is no synthetic teaser job, and notifications carry a verifiable `messageId`. |
| "Can't edit profile / change photo" | `ProfileService` exposes idempotent `PATCH /profile` and `PUT /profile/avatar`. The iOS and web clients both have a full profile editor. |
| "No real login / logout"            | `AuthService` issues short-lived JWTs + rotating refresh tokens, with explicit `/auth/logout` revocation. Sessions can be listed and revoked from the profile screen. |

## Color palette — "from your secret admirer"

| Token              | Hex       | Use                              |
| ------------------ | --------- | -------------------------------- |
| `--velvet-night`   | `#1A0B1F` | App background                   |
| `--crimson-rose`   | `#8B1538` | Primary action, hero gradient    |
| `--rose-gold`      | `#B76E79` | Secondary accent, links          |
| `--champagne`      | `#D4AF37` | Highlights, premium accents      |
| `--dusty-blush`    | `#E8C5C5` | Soft surfaces, message bubbles   |
| `--whisper`        | `#F5E6E8` | Body text on dark backgrounds    |

See `docs/color-palette.md` for tints and accessibility contrast checks.

## Architecture at a glance

```
            ┌─────────────┐         ┌──────────────────┐
  client ──▶│ ApiGateway  │──HTTP──▶│   AuthService    │──┐
            └─────────────┘         └──────────────────┘  │
                  │                                       │  publishes
                  │                  ┌──────────────────┐ │  UserRegistered
                  ├─────────────────▶│ ProfileService   │─┤
                  │                  └──────────────────┘ │
                  │                  ┌──────────────────┐ │
                  ├─────────────────▶│ MessageService   │─┤   ┌─────────────────┐
                  │                  └──────────────────┘ ├──▶│  MessageBus     │
                  │                  ┌──────────────────┐ │   │  (pub/sub)      │
                  └─────────────────▶│NotificationSvc   │◀┤   └─────────────────┘
                                     └──────────────────┘ │
                                     ┌──────────────────┐ │
                                     │ SagaOrchestrator │◀┘   coordinates
                                     └──────────────────┘     SendMessageSaga
```

- **SAGA pattern**: `SendMessageSaga` walks `ValidateSender → PersistMessage →
  IncrementInboxCounter → DispatchNotification`. Each step has a compensating
  action; the orchestrator rolls back forward-completed steps on failure.
- **Pub/Sub**: services publish `UserRegistered`, `ProfileUpdated`,
  `MessageReceived`, and `MessageRead` events. `NotificationService` and
  analytics consumers subscribe.
- **SQL**: a single schema in `web/db/schema.sql` defines `users`,
  `profiles`, `messages`, `notifications`, `refresh_tokens`, and
  `saga_state`. Each service owns its tables; cross-service reads go through
  events.

See `docs/architecture.md` for the long version.

## Running locally

### Web

```bash
cd web
dotnet build SecretAdmirer.sln
psql "$DATABASE_URL" -f db/schema.sql       # or sqlcmd for SQL Server
dotnet run --project services/AuthService
dotnet run --project services/ProfileService
dotnet run --project services/MessageService
dotnet run --project services/NotificationService
dotnet run --project services/SagaOrchestrator
dotnet run --project services/ApiGateway    # listens on :8080
cd frontend && python3 -m http.server 5173
```

### iOS

Open `ios/SecretAdmirer/` in Xcode 15+, set the `apiBaseURL` in
`Configuration.swift` to your gateway, and run on the iOS 16 simulator.

## License

Apache 2.0 — see `LICENSE`.

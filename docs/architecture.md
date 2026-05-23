# Architecture

Secret Admirer is a polyglot, multi-target product:

- **iOS client** — SwiftUI, MVVM, URLSession, Keychain for token storage.
- **Web frontend** — static HTML/CSS, vanilla JavaScript with jQuery for AJAX
  and DOM helpers. No SPA framework — the pages mirror the iOS screens.
- **Backend** — five ASP.NET Core 8 services behind an API Gateway, sharing a
  contracts / message-bus / saga library.
- **Data plane** — SQL Server / PostgreSQL (the schema in
  `web/db/schema.sql` is portable). Each service owns its tables.

## Services

### `ApiGateway`

Thin reverse proxy + auth gate. Validates the incoming JWT once, then forwards
the request to the right upstream service with `X-User-Id` / `X-User-Handle`
headers so downstream services don't re-validate signatures.

### `AuthService`

- `POST /auth/register` — create account.
- `POST /auth/login` — issue access JWT (15 min) + refresh token (30 days).
- `POST /auth/refresh` — rotate refresh token.
- `POST /auth/logout` — revoke refresh token, invalidate the device session.
- `GET  /auth/sessions` — list active sessions.
- `DELETE /auth/sessions/{id}` — revoke a remote session.

Passwords are PBKDF2 with a per-user salt. Refresh tokens are stored hashed.
On register, publishes `UserRegistered` so `ProfileService` can create a default
profile row.

### `ProfileService`

- `GET /profile/me` — own profile.
- `GET /profile/by-handle/{handle}` — public profile for the share page.
- `PATCH /profile` — partial update (display name, bio, theme, avatar URL).
- `PUT /profile/avatar` — upload avatar (multipart).
- `GET /profile/link` — returns the share URL `/u/{handle}`.

Publishes `ProfileUpdated` on every successful write.

### `MessageService`

- `POST /messages` — anonymous send (rate-limited by sender IP + receiver
  handle). Kicks off `SendMessageSaga`.
- `GET /messages/inbox` — paginated inbox for the authenticated user.
- `GET /messages/{id}` — read a single message (marks as read, publishes
  `MessageRead`).
- `DELETE /messages/{id}` — soft-delete.

Sender identity is never persisted — only a salted, one-way hash of
`(sender_ip, receiver_id, day)` for rate limiting and anti-abuse.

### `NotificationService`

Subscribes to `MessageReceived`. Persists a notification row and pushes via
APNs / WebPush. **Notifications always carry a real `messageId`** — there is
no synthetic "you have a new message from a friend!" job.

- `GET /notifications` — list.
- `POST /notifications/{id}/read` — mark read.
- WebSocket `/notifications/stream` — live updates.

### `SagaOrchestrator`

Hosts long-running sagas. `SendMessageSaga` is the primary one:

```
ValidateSender  →  PersistMessage  →  IncrementInboxCounter  →  DispatchNotification
       │                  │                       │                       │
       └── compensate ────┴─── compensate ────────┴───── compensate ──────┘
```

The orchestrator persists each step's state in `saga_state` so an in-flight
saga can recover after a crash.

## Patterns

### Pub/Sub bus

`Shared/MessageBus/IMessageBus.cs` defines `PublishAsync<T>` and
`Subscribe<T>(handler)`. Default implementation is in-process
(`InMemoryMessageBus`) and there's a `RabbitMqMessageBus` stub for production.
All events live in `Shared/Contracts/Events.cs` so producers and consumers
share types.

### SAGA

`Shared/Saga/SagaStep.cs` is `(Action, CompensatingAction)`. A saga is a list
of steps. The orchestrator executes them in order, recording state. On
failure, it walks back through completed steps and runs their compensations
in reverse.

### Trust by default

Every step that *could* lie to the user (notifications, unread counts, "X
people viewed your link") is grounded in a real bus event tied to a row in
SQL. The frontend never displays a number that isn't a SELECT.

## Failure modes & mitigation

| Failure                          | Mitigation                                                     |
| -------------------------------- | -------------------------------------------------------------- |
| AuthService down                 | Gateway returns 503; clients show retry banner, queue writes   |
| MessageService transient DB error| Saga compensates inbox counter; client gets `503 Retry-After`  |
| NotificationService backlog      | Bus has at-least-once delivery; dedupe by `messageId`          |
| Stolen JWT                       | Logout revokes refresh; access token TTL is 15 min             |
| Avatar bucket outage             | Profile keeps the old URL until the new upload commits         |

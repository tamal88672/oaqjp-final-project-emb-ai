# API reference

Base URL (local): `http://localhost:8080`

All responses are JSON. Authenticated routes require
`Authorization: Bearer <jwt>`.

## Auth

### `POST /auth/register`
```json
{ "handle": "rose", "email": "rose@example.com", "password": "********" }
```
→ `201 { "userId": "...", "accessToken": "...", "refreshToken": "..." }`

### `POST /auth/login`
```json
{ "identifier": "rose", "password": "********" }
```
→ `200 { "accessToken": "...", "refreshToken": "...", "expiresIn": 900 }`

### `POST /auth/refresh`
```json
{ "refreshToken": "..." }
```
→ `200 { "accessToken": "...", "refreshToken": "..." }`

### `POST /auth/logout`
Body: `{ "refreshToken": "..." }` → `204`

### `GET /auth/sessions` → `200 [{ "id": ..., "device": ..., "lastSeen": ... }]`

### `DELETE /auth/sessions/{id}` → `204`

## Profile

### `GET /profile/me` → `200 { "handle", "displayName", "bio", "avatarUrl", "theme" }`

### `GET /profile/by-handle/{handle}` → `200 { "handle", "displayName", "bio", "avatarUrl" }` (public subset)

### `PATCH /profile`
```json
{ "displayName": "Rose", "bio": "i bake on weekends", "theme": "velvet" }
```
→ `200` updated profile.

### `PUT /profile/avatar` (multipart `avatar=@file.jpg`) → `200 { "avatarUrl": "..." }`

### `GET /profile/link` → `200 { "url": "https://secretadmirer.app/u/rose" }`

## Messages

### `POST /messages` (anonymous, no auth)
```json
{ "receiverHandle": "rose", "body": "i think about you in line at the coffee shop" }
```
→ `202 { "messageId": "...", "sagaId": "..." }`

### `GET /messages/inbox?cursor=...&limit=20` (auth)
→ `200 { "items": [{ "id", "body", "receivedAt", "read" }], "nextCursor": "..." }`

### `GET /messages/{id}` (auth, owner-only) → `200 { ... }` (publishes `MessageRead`)

### `DELETE /messages/{id}` (auth, owner-only) → `204`

## Notifications

### `GET /notifications` (auth) → `200 [...]`
### `POST /notifications/{id}/read` (auth) → `204`
### WS `/notifications/stream` (auth) → live `{ type: "message.received", payload: { messageId } }`

## Errors

All errors follow:
```json
{ "error": { "code": "string", "message": "human-readable", "details": {...} } }
```

Codes used:

| Code                  | HTTP | Meaning                                                |
| --------------------- | ---- | ------------------------------------------------------ |
| `auth.invalid`        | 401  | Token invalid / expired                                |
| `auth.handle_taken`   | 409  | Handle already exists                                  |
| `profile.not_found`   | 404  | No profile by that handle                              |
| `message.rate_limit`  | 429  | Sender exceeded per-day quota for this receiver        |
| `message.too_long`    | 400  | Body exceeds 500 chars                                 |
| `saga.compensated`    | 503  | The send saga had to roll back; safe to retry          |

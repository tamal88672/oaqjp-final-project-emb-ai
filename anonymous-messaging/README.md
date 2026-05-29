# WhisperWall — Anonymous Messaging

A lightweight anonymous public message board where anyone can post to shared rooms without an account. Every message is signed with a random ephemeral alias (e.g. "Brave Otter", "Silent Wolf") and a colored avatar.

## Concept & purpose

WhisperWall is a confession-wall / anonymous chat board. There is no login and no accounts — people drop into public rooms and post freely. Each message gets its own randomly generated alias and avatar color assigned server-side, so posts read as anonymous and ephemeral. It's meant for honest feedback, shower thoughts, confessions, and casual anonymous chatter.

## Features

- **Anonymous aliases** — a random `adjective + animal` alias and avatar color are generated server-side for every message; no identity is ever required or stored.
- **Multiple rooms** — browse and post in separate public rooms; create your own on the fly.
- **Likes** — tap the heart on any message to bump its like count.
- **Real-time-ish** — the active room polls every 4 seconds so new messages show up automatically.
- **XSS-safe rendering** — the frontend renders all user content via `textContent`, never raw `innerHTML`.
- **Zero-config storage** — an embedded SQLite database is created and seeded on first run; no external services.

## Tech stack

- **Backend:** Node.js, Express
- **Storage:** SQLite via better-sqlite3 (embedded, file-based)
- **IDs:** uuid
- **Frontend:** vanilla HTML / CSS / JavaScript (no framework, no build step)

## Project structure

```
anonymous-messaging/
├── package.json
├── server.js            # Express server + SQLite + API
├── .gitignore
├── README.md
├── data/                # SQLite DB lives here (gitignored, auto-created)
│   └── messages.db
└── public/              # static frontend served by Express
    ├── index.html
    ├── style.css
    └── app.js
```

## Install & run

```bash
npm install
npm start
```

Then open <http://localhost:4000>.

For development with auto-reload:

```bash
npm run dev
```

The server listens on port `4000` (override with the `PORT` env var). On first run it creates `data/messages.db` and seeds the default rooms: **General**, **Confessions**, **Random Thoughts**, and **Feedback**.

## API reference

| Method | Endpoint                     | Description                                            | Body                       |
| ------ | ---------------------------- | ----------------------------------------------------- | -------------------------- |
| GET    | `/api/rooms`                 | List all rooms with message counts                    | —                          |
| POST   | `/api/rooms`                 | Create a room (409 if name already exists)            | `{ name, description? }`   |
| GET    | `/api/rooms/:id/messages`    | List messages in a room (oldest first, max 200)       | —                          |
| POST   | `/api/rooms/:id/messages`    | Post a message; server assigns alias + color (400 if room missing) | `{ content }` (max 1000)   |
| POST   | `/api/messages/:id/like`     | Increment a message's like count; returns new total   | —                          |

All endpoints return JSON. Errors come back as `{ "error": "..." }` with the appropriate status code (`400`, `404`, `409`, `500`).

## Privacy note

WhisperWall does not collect accounts, emails, or personal identifiers, and the alias shown on each message is randomly generated per message — it is not tied to any user. However, messages **are** persisted to a local SQLite database (`data/messages.db`) on the machine running the server, so they are not encrypted and are readable by anyone with access to that file. Treat it as a public, locally-stored board rather than a private or truly untraceable channel.

## Security note

User-submitted message and room text is stored verbatim. To prevent cross-site scripting (XSS), the frontend never injects raw user content with `innerHTML`; all message content, aliases, and room names are rendered through `textContent` (or an escaping helper), so any HTML in a message is displayed as plain text rather than executed.

# Projects Monorepo

This repository contains three independent applications, each self-contained in
its own folder with its own dependencies, README, and run instructions.

| Project | Folder | Stack | What it does |
|---------|--------|-------|--------------|
| Bharatiya Handicrafts | [`handicrafts/`](./handicrafts) | React + Express + SQLite | Trade management platform for an Indian handicraft export business — product catalog, inventory, reports, suppliers. |
| Emotion Detection | [`emotion-detection/`](./emotion-detection) | Python + Flask | Analyzes text and detects the dominant emotion (anger, disgust, fear, joy, sadness) with a web UI. |
| Anonymous Messaging | [`anonymous-messaging/`](./anonymous-messaging) | Node + Express + SQLite | Anonymous message board with rooms, random aliases, and likes. |

Each project runs independently. See the README inside each folder for full
details, features, API reference, and setup.

## Quick start

```bash
# Handicrafts (web app)
cd handicrafts && npm install && cd client && npm install && cd .. && npm run dev
# → http://localhost:5173

# Emotion Detection
cd emotion-detection && pip install -r requirements.txt && python server.py
# → http://localhost:5050

# Anonymous Messaging
cd anonymous-messaging && npm install && npm start
# → http://localhost:4000
```

## Repository layout

```
.
├── handicrafts/          # React + Express handicraft trade platform
├── emotion-detection/    # Flask text-emotion analyzer
├── anonymous-messaging/  # Express anonymous message board
├── LICENSE
└── README.md
```

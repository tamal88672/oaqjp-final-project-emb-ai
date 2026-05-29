const path = require('path');
const fs = require('fs');
const express = require('express');
const Database = require('better-sqlite3');
const { v4: uuid } = require('uuid');

const PORT = process.env.PORT || 4000;
const DATA_DIR = path.join(__dirname, 'data');
const DB_PATH = path.join(DATA_DIR, 'messages.db');
const MAX_CONTENT_LENGTH = 1000;

const ADJECTIVES = [
  'Brave', 'Silent', 'Mystery', 'Hidden', 'Curious', 'Witty', 'Gentle',
  'Bold', 'Quiet', 'Clever', 'Swift', 'Cosmic', 'Dreamy', 'Fuzzy',
  'Lucky', 'Noble', 'Sly', 'Wandering', 'Velvet', 'Electric'
];

const ANIMALS = [
  'Otter', 'Wolf', 'Fox', 'Tiger', 'Panda', 'Raven', 'Falcon', 'Lynx',
  'Badger', 'Heron', 'Koala', 'Moose', 'Owl', 'Seal', 'Hawk', 'Bison',
  'Gecko', 'Newt', 'Quokka', 'Mantis'
];

const COLORS = [
  '#ef4444', '#f97316', '#f59e0b', '#eab308', '#84cc16', '#22c55e',
  '#10b981', '#14b8a6', '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1',
  '#8b5cf6', '#a855f7', '#d946ef', '#ec4899', '#f43f5e'
];

const SEED_ROOMS = [
  { name: 'General', description: 'Talk about anything and everything.' },
  { name: 'Confessions', description: 'Get it off your chest, anonymously.' },
  { name: 'Random Thoughts', description: 'The shower-thoughts channel.' },
  { name: 'Feedback', description: 'Ideas, suggestions, and honest opinions.' }
];

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function randomAlias() {
  return `${pick(ADJECTIVES)} ${pick(ANIMALS)}`;
}

function randomColor() {
  return pick(COLORS);
}

let db;

function getDb() {
  if (db) return db;

  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }

  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  db.exec(`
    CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      content TEXT NOT NULL,
      alias TEXT,
      color TEXT,
      likes INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (room_id) REFERENCES rooms(id)
    );

    CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id, created_at);
  `);

  seedRooms();
  return db;
}

function seedRooms() {
  const count = db.prepare('SELECT COUNT(*) AS n FROM rooms').get().n;
  if (count > 0) return;

  const insert = db.prepare(
    'INSERT INTO rooms (id, name, description) VALUES (?, ?, ?)'
  );
  const seed = db.transaction((rooms) => {
    for (const room of rooms) {
      insert.run(uuid(), room.name, room.description);
    }
  });
  seed(SEED_ROOMS);
}

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/rooms', (req, res) => {
  try {
    const rooms = getDb()
      .prepare(`
        SELECT r.id, r.name, r.description, r.created_at,
               COUNT(m.id) AS message_count
        FROM rooms r
        LEFT JOIN messages m ON m.room_id = r.id
        GROUP BY r.id
        ORDER BY r.created_at ASC
      `)
      .all();
    res.json(rooms);
  } catch (err) {
    console.error('GET /api/rooms failed:', err);
    res.status(500).json({ error: 'Failed to load rooms.' });
  }
});

app.post('/api/rooms', (req, res) => {
  try {
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    const description =
      typeof req.body.description === 'string' ? req.body.description.trim() : '';

    if (!name) {
      return res.status(400).json({ error: 'Room name is required.' });
    }
    if (name.length > 60) {
      return res.status(400).json({ error: 'Room name is too long (max 60).' });
    }

    const conn = getDb();
    const existing = conn
      .prepare('SELECT id FROM rooms WHERE name = ? COLLATE NOCASE')
      .get(name);
    if (existing) {
      return res.status(409).json({ error: 'A room with that name already exists.' });
    }

    const id = uuid();
    conn
      .prepare('INSERT INTO rooms (id, name, description) VALUES (?, ?, ?)')
      .run(id, name, description);

    const room = conn
      .prepare(
        `SELECT id, name, description, created_at, 0 AS message_count
         FROM rooms WHERE id = ?`
      )
      .get(id);
    res.status(201).json(room);
  } catch (err) {
    console.error('POST /api/rooms failed:', err);
    res.status(500).json({ error: 'Failed to create room.' });
  }
});

app.get('/api/rooms/:id/messages', (req, res) => {
  try {
    const conn = getDb();
    const room = conn.prepare('SELECT id FROM rooms WHERE id = ?').get(req.params.id);
    if (!room) {
      return res.status(404).json({ error: 'Room not found.' });
    }

    const messages = conn
      .prepare(`
        SELECT id, content, alias, color, likes, created_at
        FROM messages
        WHERE room_id = ?
        ORDER BY created_at ASC, rowid ASC
        LIMIT 200
      `)
      .all(req.params.id);
    res.json(messages);
  } catch (err) {
    console.error('GET /api/rooms/:id/messages failed:', err);
    res.status(500).json({ error: 'Failed to load messages.' });
  }
});

app.post('/api/rooms/:id/messages', (req, res) => {
  try {
    const conn = getDb();
    const room = conn.prepare('SELECT id FROM rooms WHERE id = ?').get(req.params.id);
    if (!room) {
      return res.status(400).json({ error: 'Room does not exist.' });
    }

    const content = typeof req.body.content === 'string' ? req.body.content.trim() : '';
    if (!content) {
      return res.status(400).json({ error: 'Message content is required.' });
    }
    if (content.length > MAX_CONTENT_LENGTH) {
      return res
        .status(400)
        .json({ error: `Message is too long (max ${MAX_CONTENT_LENGTH}).` });
    }

    const id = uuid();
    const alias = randomAlias();
    const color = randomColor();
    conn
      .prepare(
        `INSERT INTO messages (id, room_id, content, alias, color)
         VALUES (?, ?, ?, ?, ?)`
      )
      .run(id, req.params.id, content, alias, color);

    const message = conn
      .prepare(
        `SELECT id, content, alias, color, likes, created_at
         FROM messages WHERE id = ?`
      )
      .get(id);
    res.status(201).json(message);
  } catch (err) {
    console.error('POST /api/rooms/:id/messages failed:', err);
    res.status(500).json({ error: 'Failed to post message.' });
  }
});

app.post('/api/messages/:id/like', (req, res) => {
  try {
    const conn = getDb();
    const result = conn
      .prepare('UPDATE messages SET likes = likes + 1 WHERE id = ?')
      .run(req.params.id);
    if (result.changes === 0) {
      return res.status(404).json({ error: 'Message not found.' });
    }

    const { likes } = conn
      .prepare('SELECT likes FROM messages WHERE id = ?')
      .get(req.params.id);
    res.json({ likes });
  } catch (err) {
    console.error('POST /api/messages/:id/like failed:', err);
    res.status(500).json({ error: 'Failed to like message.' });
  }
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not found.' });
});

app.listen(PORT, () => {
  getDb();
  console.log(`WhisperWall running at http://localhost:${PORT}`);
});

module.exports = app;

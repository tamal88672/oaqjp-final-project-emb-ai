const Database = require('better-sqlite3');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

let db = null;

function getDb() {
  if (db) return db;

  const dbPath = path.join(__dirname, 'data', 'handicraft.db');
  db = new Database(dbPath);

  // Enable WAL mode for better concurrent performance
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');

  createTables();
  seedCategories();

  return db;
}

function createTables() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      description TEXT,
      image_url TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      category_id TEXT,
      price_inr REAL,
      price_usd REAL,
      image_url TEXT,
      origin_state TEXT,
      artisan_name TEXT,
      artisan_story TEXT,
      sku TEXT UNIQUE,
      status TEXT DEFAULT 'available' CHECK(status IN ('available', 'out_of_stock', 'coming_soon')),
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    );

    CREATE TABLE IF NOT EXISTS inventory (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL UNIQUE,
      quantity INTEGER DEFAULT 0,
      min_stock_level INTEGER DEFAULT 5,
      warehouse_location TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (product_id) REFERENCES products(id)
    );

    CREATE TABLE IF NOT EXISTS inventory_log (
      id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      change_type TEXT NOT NULL CHECK(change_type IN ('added', 'removed', 'adjusted', 'initial')),
      quantity_change INTEGER,
      previous_quantity INTEGER,
      new_quantity INTEGER,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (product_id) REFERENCES products(id)
    );

    CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      contact_person TEXT,
      email TEXT,
      phone TEXT,
      address TEXT,
      city TEXT,
      state TEXT,
      country TEXT DEFAULT 'India',
      specialization TEXT,
      notes TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);
}

function seedCategories() {
  const count = db.prepare('SELECT COUNT(*) as count FROM categories').get();
  if (count.count > 0) return;

  const defaultCategories = [
    { name: 'Jute Products', description: 'Eco-friendly products made from natural jute fiber, including bags, rugs, and home decor items.' },
    { name: 'Terracotta & Pottery', description: 'Traditional clay-based pottery and terracotta items, handcrafted by skilled artisans.' },
    { name: 'Brass & Metal Craft', description: 'Exquisite metalwork including brass utensils, figurines, and decorative items.' },
    { name: 'Handloom Textiles', description: 'Hand-woven fabrics and textiles showcasing traditional Indian weaving techniques.' },
    { name: 'Wooden Handicrafts', description: 'Carved and crafted wooden items including furniture, toys, and decorative pieces.' },
    { name: 'Bamboo & Cane', description: 'Sustainable bamboo and cane products including baskets, furniture, and utility items.' },
    { name: 'Leather Craft', description: 'Handcrafted leather goods including bags, wallets, footwear, and accessories.' },
    { name: 'Embroidery & Needlework', description: 'Intricate hand-embroidered textiles featuring traditional Indian embroidery styles.' },
  ];

  const insert = db.prepare(
    'INSERT INTO categories (id, name, description) VALUES (?, ?, ?)'
  );

  const insertMany = db.transaction((categories) => {
    for (const cat of categories) {
      insert.run(uuidv4(), cat.name, cat.description);
    }
  });

  insertMany(defaultCategories);
}

module.exports = { getDb };

const express = require('express');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');

const router = express.Router();

// Multer config
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, '..', 'uploads'));
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
  },
});

// Helper: generate SKU
function generateSku(db, categoryId) {
  let prefix = 'GEN';
  if (categoryId) {
    const cat = db.prepare('SELECT name FROM categories WHERE id = ?').get(categoryId);
    if (cat) {
      // Take first 3 letters of category name, uppercase
      prefix = cat.name.replace(/[^a-zA-Z]/g, '').substring(0, 3).toUpperCase();
    }
  }
  const digits = String(Math.floor(1000 + Math.random() * 9000));
  return `HC-${prefix}-${digits}`;
}

// GET / — list all products with filters and sorting
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const { category_id, status, search, sort, min_price, max_price } = req.query;

    let sql = `
      SELECT p.*, c.name as category_name, COALESCE(i.quantity, 0) as quantity
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN inventory i ON i.product_id = p.id
      WHERE 1=1
    `;
    const params = [];

    if (category_id) {
      sql += ' AND p.category_id = ?';
      params.push(category_id);
    }

    if (status) {
      sql += ' AND p.status = ?';
      params.push(status);
    }

    if (search) {
      sql += ' AND (p.name LIKE ? OR p.sku LIKE ?)';
      const searchTerm = `%${search}%`;
      params.push(searchTerm, searchTerm);
    }

    if (min_price) {
      sql += ' AND p.price_usd >= ?';
      params.push(Number(min_price));
    }

    if (max_price) {
      sql += ' AND p.price_usd <= ?';
      params.push(Number(max_price));
    }

    switch (sort) {
      case 'price_asc':
        sql += ' ORDER BY p.price_usd ASC';
        break;
      case 'price_desc':
        sql += ' ORDER BY p.price_usd DESC';
        break;
      case 'newest':
      default:
        sql += ' ORDER BY p.created_at DESC';
        break;
    }

    const products = db.prepare(sql).all(...params);
    res.json(products);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /:id — single product with full details
router.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const product = db.prepare(`
      SELECT p.*, c.name as category_name,
             COALESCE(i.quantity, 0) as quantity,
             i.min_stock_level,
             i.warehouse_location
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN inventory i ON i.product_id = p.id
      WHERE p.id = ?
    `).get(req.params.id);

    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST / — create product with image upload
router.post('/', upload.single('image'), (req, res) => {
  try {
    const db = getDb();
    const {
      name, description, category_id, price_inr, price_usd,
      origin_state, artisan_name, artisan_story, status,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Product name is required' });
    }

    const id = uuidv4();
    const sku = generateSku(db, category_id);
    const image_url = req.file ? `/uploads/${req.file.filename}` : null;

    db.prepare(`
      INSERT INTO products (id, name, description, category_id, price_inr, price_usd,
        image_url, origin_state, artisan_name, artisan_story, sku, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      name.trim(),
      description || null,
      category_id || null,
      price_inr ? Number(price_inr) : null,
      price_usd ? Number(price_usd) : null,
      image_url,
      origin_state || null,
      artisan_name || null,
      artisan_story || null,
      sku,
      status || 'available'
    );

    // Create initial inventory record
    const inventoryId = uuidv4();
    db.prepare(
      'INSERT INTO inventory (id, product_id, quantity) VALUES (?, ?, 0)'
    ).run(inventoryId, id);

    // Create initial inventory log entry
    const logId = uuidv4();
    db.prepare(`
      INSERT INTO inventory_log (id, product_id, change_type, quantity_change, previous_quantity, new_quantity, notes)
      VALUES (?, ?, 'initial', 0, 0, 0, 'Product created with initial inventory')
    `).run(logId, id);

    const product = db.prepare(`
      SELECT p.*, c.name as category_name, COALESCE(i.quantity, 0) as quantity
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN inventory i ON i.product_id = p.id
      WHERE p.id = ?
    `).get(id);

    res.status(201).json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /:id — update product
router.put('/:id', upload.single('image'), (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const {
      name, description, category_id, price_inr, price_usd,
      origin_state, artisan_name, artisan_story, status,
    } = req.body;

    const image_url = req.file ? `/uploads/${req.file.filename}` : existing.image_url;

    db.prepare(`
      UPDATE products
      SET name = ?, description = ?, category_id = ?, price_inr = ?, price_usd = ?,
          image_url = ?, origin_state = ?, artisan_name = ?, artisan_story = ?,
          status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      name ? name.trim() : existing.name,
      description !== undefined ? description : existing.description,
      category_id !== undefined ? category_id : existing.category_id,
      price_inr !== undefined ? Number(price_inr) : existing.price_inr,
      price_usd !== undefined ? Number(price_usd) : existing.price_usd,
      image_url,
      origin_state !== undefined ? origin_state : existing.origin_state,
      artisan_name !== undefined ? artisan_name : existing.artisan_name,
      artisan_story !== undefined ? artisan_story : existing.artisan_story,
      status || existing.status,
      req.params.id
    );

    const product = db.prepare(`
      SELECT p.*, c.name as category_name, COALESCE(i.quantity, 0) as quantity
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN inventory i ON i.product_id = p.id
      WHERE p.id = ?
    `).get(req.params.id);

    res.json(product);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /:id — delete product and its inventory/logs
router.delete('/:id', (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const deleteAll = db.transaction(() => {
      db.prepare('DELETE FROM inventory_log WHERE product_id = ?').run(req.params.id);
      db.prepare('DELETE FROM inventory WHERE product_id = ?').run(req.params.id);
      db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
    });

    deleteAll();
    res.json({ message: 'Product deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

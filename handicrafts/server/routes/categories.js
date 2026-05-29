const express = require('express');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');

const router = express.Router();

// Multer config for image uploads
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
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
  },
});

// GET / — list all categories with product count
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const categories = db.prepare(`
      SELECT c.*, COUNT(p.id) as product_count
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    `).all();
    res.json(categories);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /:id — get single category with its products
router.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);
    if (!category) {
      return res.status(404).json({ error: 'Category not found' });
    }

    const products = db.prepare(`
      SELECT p.*, COALESCE(i.quantity, 0) as quantity
      FROM products p
      LEFT JOIN inventory i ON i.product_id = p.id
      WHERE p.category_id = ?
      ORDER BY p.created_at DESC
    `).all(req.params.id);

    res.json({ ...category, products });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST / — create category
router.post('/', upload.single('image'), (req, res) => {
  try {
    const db = getDb();
    const { name, description } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Category name is required' });
    }

    const id = uuidv4();
    const image_url = req.file ? `/uploads/${req.file.filename}` : null;

    db.prepare(
      'INSERT INTO categories (id, name, description, image_url) VALUES (?, ?, ?, ?)'
    ).run(id, name.trim(), description || null, image_url);

    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(id);
    res.status(201).json(category);
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'A category with this name already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// PUT /:id — update category
router.put('/:id', upload.single('image'), (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Category not found' });
    }

    const { name, description } = req.body;
    const image_url = req.file ? `/uploads/${req.file.filename}` : existing.image_url;

    db.prepare(`
      UPDATE categories
      SET name = ?, description = ?, image_url = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      name ? name.trim() : existing.name,
      description !== undefined ? description : existing.description,
      image_url,
      req.params.id
    );

    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);
    res.json(category);
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'A category with this name already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// DELETE /:id — delete category (only if no products)
router.delete('/:id', (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Category not found' });
    }

    const productCount = db.prepare(
      'SELECT COUNT(*) as count FROM products WHERE category_id = ?'
    ).get(req.params.id);

    if (productCount.count > 0) {
      return res.status(400).json({
        error: `Cannot delete category: ${productCount.count} product(s) still assigned to it`,
      });
    }

    db.prepare('DELETE FROM categories WHERE id = ?').run(req.params.id);
    res.json({ message: 'Category deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

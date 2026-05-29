const express = require('express');
const { getDb } = require('../database');

const router = express.Router();

// GET /activity — activity log with date filters
router.get('/activity', (req, res) => {
  try {
    const db = getDb();
    const { from, to, product_id } = req.query;

    let sql = `
      SELECT il.*, p.name as product_name, p.sku
      FROM inventory_log il
      JOIN products p ON p.id = il.product_id
      WHERE 1=1
    `;
    const params = [];

    if (from) {
      sql += ' AND il.created_at >= ?';
      params.push(from);
    }

    if (to) {
      sql += ' AND il.created_at <= ?';
      params.push(to);
    }

    if (product_id) {
      sql += ' AND il.product_id = ?';
      params.push(product_id);
    }

    sql += ' ORDER BY il.created_at DESC LIMIT 100';

    const logs = db.prepare(sql).all(...params);
    res.json(logs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /summary — dashboard summary
router.get('/summary', (req, res) => {
  try {
    const db = getDb();

    const totalProducts = db.prepare('SELECT COUNT(*) as count FROM products').get().count;
    const totalCategories = db.prepare('SELECT COUNT(*) as count FROM categories').get().count;

    const inventoryValue = db.prepare(`
      SELECT COALESCE(SUM(i.quantity * p.price_usd), 0) as total_value
      FROM inventory i
      JOIN products p ON p.id = i.product_id
    `).get().total_value;

    const lowStockCount = db.prepare(`
      SELECT COUNT(*) as count
      FROM inventory i
      WHERE i.quantity > 0 AND i.quantity <= i.min_stock_level
    `).get().count;

    const outOfStockCount = db.prepare(`
      SELECT COUNT(*) as count
      FROM inventory i
      WHERE i.quantity = 0
    `).get().count;

    const recentlyAdded = db.prepare(`
      SELECT COUNT(*) as count
      FROM products
      WHERE created_at >= datetime('now', '-7 days')
    `).get().count;

    res.json({
      total_products: totalProducts,
      total_categories: totalCategories,
      total_inventory_value: Math.round(inventoryValue * 100) / 100,
      low_stock_count: lowStockCount,
      out_of_stock_count: outOfStockCount,
      recently_added: recentlyAdded,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /category-breakdown — products per category with total value
router.get('/category-breakdown', (req, res) => {
  try {
    const db = getDb();
    const breakdown = db.prepare(`
      SELECT c.id, c.name,
             COUNT(p.id) as product_count,
             COALESCE(SUM(i.quantity * p.price_usd), 0) as total_value
      FROM categories c
      LEFT JOIN products p ON p.category_id = c.id
      LEFT JOIN inventory i ON i.product_id = p.id
      GROUP BY c.id
      ORDER BY total_value DESC
    `).all();

    // Round values
    const result = breakdown.map(row => ({
      ...row,
      total_value: Math.round(row.total_value * 100) / 100,
    }));

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

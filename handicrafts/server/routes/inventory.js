const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');

const router = express.Router();

// GET /alerts — products with low or zero stock (defined before /:productId to avoid route conflict)
router.get('/alerts', (req, res) => {
  try {
    const db = getDb();
    const alerts = db.prepare(`
      SELECT p.id, p.name, p.sku, p.status, c.name as category_name,
             i.quantity, i.min_stock_level, i.warehouse_location,
             CASE
               WHEN i.quantity = 0 THEN 'out'
               WHEN i.quantity <= i.min_stock_level THEN 'low'
             END as stock_status
      FROM inventory i
      JOIN products p ON p.id = i.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE i.quantity = 0 OR i.quantity <= i.min_stock_level
      ORDER BY i.quantity ASC
    `).all();

    res.json(alerts);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET / — list all inventory with product name, category, stock status
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const inventory = db.prepare(`
      SELECT i.*, p.name as product_name, p.sku, p.status as product_status,
             c.name as category_name,
             CASE
               WHEN i.quantity = 0 THEN 'out'
               WHEN i.quantity <= i.min_stock_level THEN 'low'
               ELSE 'ok'
             END as stock_status
      FROM inventory i
      JOIN products p ON p.id = i.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      ORDER BY i.quantity ASC
    `).all();

    res.json(inventory);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /:productId — update inventory quantity
router.put('/:productId', (req, res) => {
  try {
    const db = getDb();
    const { quantity, change_type, notes, min_stock_level, warehouse_location } = req.body;

    if (quantity === undefined || quantity === null) {
      return res.status(400).json({ error: 'Quantity is required' });
    }

    const newQuantity = Number(quantity);
    if (isNaN(newQuantity) || newQuantity < 0) {
      return res.status(400).json({ error: 'Quantity must be a non-negative number' });
    }

    const existing = db.prepare(
      'SELECT * FROM inventory WHERE product_id = ?'
    ).get(req.params.productId);

    if (!existing) {
      return res.status(404).json({ error: 'Inventory record not found for this product' });
    }

    const previousQuantity = existing.quantity;
    const quantityChange = newQuantity - previousQuantity;

    const updateAndLog = db.transaction(() => {
      // Update inventory
      const updateFields = ['quantity = ?', 'updated_at = CURRENT_TIMESTAMP'];
      const updateParams = [newQuantity];

      if (min_stock_level !== undefined) {
        updateFields.push('min_stock_level = ?');
        updateParams.push(Number(min_stock_level));
      }

      if (warehouse_location !== undefined) {
        updateFields.push('warehouse_location = ?');
        updateParams.push(warehouse_location);
      }

      updateParams.push(req.params.productId);

      db.prepare(`
        UPDATE inventory SET ${updateFields.join(', ')} WHERE product_id = ?
      `).run(...updateParams);

      // Log the change
      const logId = uuidv4();
      const logChangeType = change_type || (quantityChange > 0 ? 'added' : quantityChange < 0 ? 'removed' : 'adjusted');

      db.prepare(`
        INSERT INTO inventory_log (id, product_id, change_type, quantity_change, previous_quantity, new_quantity, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `).run(logId, req.params.productId, logChangeType, quantityChange, previousQuantity, newQuantity, notes || null);

      // Update product status based on quantity
      if (newQuantity === 0) {
        db.prepare("UPDATE products SET status = 'out_of_stock', updated_at = CURRENT_TIMESTAMP WHERE id = ?")
          .run(req.params.productId);
      } else if (previousQuantity === 0 && newQuantity > 0) {
        db.prepare("UPDATE products SET status = 'available', updated_at = CURRENT_TIMESTAMP WHERE id = ?")
          .run(req.params.productId);
      }
    });

    updateAndLog();

    const updated = db.prepare(`
      SELECT i.*, p.name as product_name, p.sku, c.name as category_name,
             CASE
               WHEN i.quantity = 0 THEN 'out'
               WHEN i.quantity <= i.min_stock_level THEN 'low'
               ELSE 'ok'
             END as stock_status
      FROM inventory i
      JOIN products p ON p.id = i.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE i.product_id = ?
    `).get(req.params.productId);

    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

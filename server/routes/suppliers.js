const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');

const router = express.Router();

// GET / — list all suppliers, support ?search
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const { search } = req.query;

    let sql = 'SELECT * FROM suppliers WHERE 1=1';
    const params = [];

    if (search) {
      sql += ' AND (name LIKE ? OR contact_person LIKE ? OR city LIKE ? OR state LIKE ? OR specialization LIKE ?)';
      const searchTerm = `%${search}%`;
      params.push(searchTerm, searchTerm, searchTerm, searchTerm, searchTerm);
    }

    sql += ' ORDER BY name ASC';

    const suppliers = db.prepare(sql).all(...params);
    res.json(suppliers);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /:id — single supplier
router.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const supplier = db.prepare('SELECT * FROM suppliers WHERE id = ?').get(req.params.id);

    if (!supplier) {
      return res.status(404).json({ error: 'Supplier not found' });
    }

    res.json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST / — create supplier
router.post('/', (req, res) => {
  try {
    const db = getDb();
    const {
      name, contact_person, email, phone, address,
      city, state, country, specialization, notes,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Supplier name is required' });
    }

    const id = uuidv4();

    db.prepare(`
      INSERT INTO suppliers (id, name, contact_person, email, phone, address, city, state, country, specialization, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      name.trim(),
      contact_person || null,
      email || null,
      phone || null,
      address || null,
      city || null,
      state || null,
      country || 'India',
      specialization || null,
      notes || null
    );

    const supplier = db.prepare('SELECT * FROM suppliers WHERE id = ?').get(id);
    res.status(201).json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /:id — update supplier
router.put('/:id', (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM suppliers WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Supplier not found' });
    }

    const {
      name, contact_person, email, phone, address,
      city, state, country, specialization, notes,
    } = req.body;

    db.prepare(`
      UPDATE suppliers
      SET name = ?, contact_person = ?, email = ?, phone = ?, address = ?,
          city = ?, state = ?, country = ?, specialization = ?, notes = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(
      name ? name.trim() : existing.name,
      contact_person !== undefined ? contact_person : existing.contact_person,
      email !== undefined ? email : existing.email,
      phone !== undefined ? phone : existing.phone,
      address !== undefined ? address : existing.address,
      city !== undefined ? city : existing.city,
      state !== undefined ? state : existing.state,
      country !== undefined ? country : existing.country,
      specialization !== undefined ? specialization : existing.specialization,
      notes !== undefined ? notes : existing.notes,
      req.params.id
    );

    const supplier = db.prepare('SELECT * FROM suppliers WHERE id = ?').get(req.params.id);
    res.json(supplier);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /:id — delete supplier
router.delete('/:id', (req, res) => {
  try {
    const db = getDb();
    const existing = db.prepare('SELECT * FROM suppliers WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Supplier not found' });
    }

    db.prepare('DELETE FROM suppliers WHERE id = ?').run(req.params.id);
    res.json({ message: 'Supplier deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

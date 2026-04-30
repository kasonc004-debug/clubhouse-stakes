const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const db     = require('../config/database');

function signToken(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

// POST /api/auth/signup
async function signup(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const { name, email, password, handicap = 0, city } = req.body;

  try {
    const exists = await db.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
    if (exists.rows.length) return res.status(409).json({ error: 'Email already registered' });

    const passwordHash = await bcrypt.hash(password, 10);
    const { rows } = await db.query(
      `INSERT INTO users (name, email, password_hash, handicap, city)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, handicap, city, is_admin, created_at`,
      [name, email.toLowerCase(), passwordHash, handicap, city]
    );

    const user  = rows[0];
    const token = signToken(user.id);
    res.status(201).json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error during signup' });
  }
}

// POST /api/auth/login
async function login(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const { email, password } = req.body;

  try {
    const { rows } = await db.query(
      'SELECT * FROM users WHERE email = $1',
      [email.toLowerCase()]
    );
    if (!rows.length) return res.status(401).json({ error: 'Invalid email or password' });

    const user = rows[0];
    if (!user.password_hash) return res.status(401).json({ error: 'Use Apple Sign-In for this account' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

    const token = signToken(user.id);
    const { password_hash: _, ...safeUser } = user;
    res.json({ token, user: safeUser });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error during login' });
  }
}

// POST /api/auth/apple
async function appleSignIn(req, res) {
  const { appleId, name, email } = req.body;
  if (!appleId) return res.status(422).json({ error: 'appleId is required' });

  try {
    let { rows } = await db.query('SELECT * FROM users WHERE apple_id = $1', [appleId]);

    let user;
    if (rows.length) {
      user = rows[0];
    } else {
      // First-time Apple Sign-In
      const insertResult = await db.query(
        `INSERT INTO users (name, email, apple_id)
         VALUES ($1, $2, $3)
         RETURNING id, name, email, handicap, city, is_admin, created_at`,
        [name || 'Golfer', email?.toLowerCase() || null, appleId]
      );
      user = insertResult.rows[0];
    }

    const token = signToken(user.id);
    const { password_hash: _, ...safeUser } = user;
    res.json({ token, user: safeUser });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error during Apple Sign-In' });
  }
}

// GET /api/auth/me
async function getMe(req, res) {
  res.json({ user: req.user });
}

// PATCH /api/auth/me
async function updateMe(req, res) {
  const { name, handicap, city } = req.body;
  const updates = [];
  const values  = [];
  let idx = 1;

  if (name     !== undefined) { updates.push(`name = $${idx++}`);     values.push(name); }
  if (handicap !== undefined) { updates.push(`handicap = $${idx++}`); values.push(handicap); }
  if (city     !== undefined) { updates.push(`city = $${idx++}`);     values.push(city); }

  if (!updates.length) return res.status(422).json({ error: 'No fields to update' });

  values.push(req.user.id);
  try {
    const { rows } = await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}
       RETURNING id, name, email, handicap, city, is_admin, created_at`,
      values
    );
    res.json({ user: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update profile' });
  }
}

module.exports = { signup, login, appleSignIn, getMe, updateMe };

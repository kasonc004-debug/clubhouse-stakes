const jwt = require('jsonwebtoken');
const db  = require('../config/database');

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const { rows } = await db.query(
      'SELECT id, name, email, handicap, city, is_admin FROM users WHERE id = $1',
      [payload.userId]
    );
    if (!rows.length) return res.status(401).json({ error: 'User not found' });
    req.user = rows[0];
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

async function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return next();
  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const { rows } = await db.query(
      'SELECT id, name, email, handicap, city, is_admin FROM users WHERE id = $1',
      [payload.userId]
    );
    if (rows.length) req.user = rows[0];
  } catch { /* ignore invalid tokens */ }
  next();
}

function requireAdmin(req, res, next) {
  if (!req.user?.is_admin) {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

module.exports = { requireAuth, requireAdmin, optionalAuth };

const db = require('../config/database');

// Internal helper — fan out a notification to a list of users.
// Designed to be called from other controllers (e.g. tournament create).
async function notify({ userIds, type, title, body = null, link = null, payload = {} }) {
  if (!Array.isArray(userIds) || userIds.length === 0) return;
  const dedup = [...new Set(userIds.filter(Boolean))];
  if (!dedup.length) return;

  // Single multi-row insert.
  const values = [];
  const tuples = dedup.map((uid, i) => {
    const off = i * 5;
    values.push(uid, type, title, body, link);
    return `($${off + 1}, $${off + 2}, $${off + 3}, $${off + 4}, $${off + 5}, $${dedup.length * 5 + 1})`;
  });
  values.push(JSON.stringify(payload));

  try {
    await db.query(
      `INSERT INTO notifications (user_id, type, title, body, link, payload)
       VALUES ${tuples.join(', ')}`,
      values
    );
  } catch (err) {
    console.error('notify failed:', err.message);
  }
}

// GET /api/notifications?unread_only=true&limit=50
async function listMine(req, res) {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
  const unreadOnly = req.query.unread_only === 'true';
  try {
    const { rows } = await db.query(
      `SELECT id, type, title, body, link, payload, read_at, created_at
       FROM notifications
       WHERE user_id = $1 ${unreadOnly ? 'AND read_at IS NULL' : ''}
       ORDER BY created_at DESC
       LIMIT $2`,
      [req.user.id, limit]
    );
    const { rows: countRows } = await db.query(
      'SELECT COUNT(*)::int AS unread FROM notifications WHERE user_id = $1 AND read_at IS NULL',
      [req.user.id]
    );
    res.json({ notifications: rows, unread: countRows[0].unread });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load notifications' });
  }
}

// POST /api/notifications/:id/read
async function markRead(req, res) {
  try {
    const { rows } = await db.query(
      `UPDATE notifications
         SET read_at = NOW()
       WHERE id = $1 AND user_id = $2 AND read_at IS NULL
       RETURNING id`,
      [req.params.id, req.user.id]
    );
    res.json({ id: rows[0]?.id || null });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed' });
  }
}

// POST /api/notifications/read-all
async function markAllRead(req, res) {
  try {
    await db.query(
      'UPDATE notifications SET read_at = NOW() WHERE user_id = $1 AND read_at IS NULL',
      [req.user.id]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed' });
  }
}

module.exports = { notify, listMine, markRead, markAllRead };

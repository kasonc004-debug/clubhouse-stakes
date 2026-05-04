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
  const lcEmail = email.toLowerCase();

  try {
    const exists = await db.query('SELECT id FROM users WHERE email = $1', [lcEmail]);
    if (exists.rows.length) return res.status(409).json({ error: 'Email already registered' });

    const passwordHash = await bcrypt.hash(password, 10);
    const { rows } = await db.query(
      `INSERT INTO users (name, email, password_hash, handicap, city)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, email, handicap, city, is_admin, created_at`,
      [name, lcEmail, passwordHash, handicap, city]
    );

    const user  = rows[0];

    // Auto-attach any pending email invites for this address.
    try {
      const attached = await applyPendingEmailInvites(user.id, lcEmail);
      if (attached.length) user.attached_clubhouses = attached;
    } catch (attachErr) {
      console.error('attach invites failed:', attachErr.message);
    }

    const token = signToken(user.id);
    res.status(201).json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error during signup' });
  }
}

// Mark every pending invite for this email as accepted, and insert
// clubhouse memberships for the new user. Returns the list of slugs attached.
async function applyPendingEmailInvites(userId, lcEmail) {
  const { rows: invites } = await db.query(
    `SELECT id, clubhouse_id FROM clubhouse_email_invites
     WHERE LOWER(email) = $1 AND accepted_at IS NULL`,
    [lcEmail]
  );
  if (!invites.length) return [];

  const attachedSlugs = [];
  for (const inv of invites) {
    await db.query(
      `INSERT INTO clubhouse_members (clubhouse_id, user_id, status, invited_by)
       VALUES ($1, $2, 'member', NULL)
       ON CONFLICT (clubhouse_id, user_id) DO UPDATE SET status = 'member'`,
      [inv.clubhouse_id, userId]
    );
    await db.query(
      `UPDATE clubhouse_email_invites
         SET accepted_at = NOW(), accepted_user = $1
       WHERE id = $2`,
      [userId, inv.id]
    );
    const { rows: ch } = await db.query(
      'SELECT slug FROM clubhouses WHERE id = $1', [inv.clubhouse_id]
    );
    if (ch.length) attachedSlugs.push(ch[0].slug);
  }
  return attachedSlugs;
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
    if (!user.password_hash) return res.status(401).json({ error: 'Invalid email or password' });

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

// GET /api/auth/me
async function getMe(req, res) {
  res.json({ user: req.user });
}

// PATCH /api/auth/me
async function updateMe(req, res) {
  const { name, handicap, city, profile_picture_url } = req.body;
  const updates = [];
  const values  = [];
  let idx = 1;

  if (name                !== undefined) { updates.push(`name = $${idx++}`);                values.push(name); }
  if (handicap            !== undefined) { updates.push(`handicap = $${idx++}`);            values.push(handicap); }
  if (city                !== undefined) { updates.push(`city = $${idx++}`);                values.push(city); }
  if (profile_picture_url !== undefined) { updates.push(`profile_picture_url = $${idx++}`); values.push(profile_picture_url); }

  if (!updates.length) return res.status(422).json({ error: 'No fields to update' });

  values.push(req.user.id);
  try {
    const { rows } = await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}
       RETURNING id, name, email, handicap, city, profile_picture_url, is_admin, created_at`,
      values
    );
    res.json({ user: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update profile' });
  }
}

// GET /api/auth/stats
async function getMyStats(req, res) {
  const userId = req.user.id;
  try {
    const { rows } = await db.query(
      `WITH
       individual_ranked AS (
         SELECT
           e.user_id,
           RANK() OVER (
             PARTITION BY e.tournament_id
             ORDER BY e.net_score ASC NULLS LAST
           ) AS rank
         FROM entries e
         JOIN tournaments t ON t.id = e.tournament_id
         WHERE t.format = 'individual'
           AND t.status = 'completed'
           AND e.gross_score IS NOT NULL
       ),
       ind_golds   AS (SELECT COUNT(*)::int AS cnt FROM individual_ranked WHERE user_id=$1 AND rank=1),
       ind_silvers AS (SELECT COUNT(*)::int AS cnt FROM individual_ranked WHERE user_id=$1 AND rank=2),
       ind_bronzes AS (SELECT COUNT(*)::int AS cnt FROM individual_ranked WHERE user_id=$1 AND rank=3),
       fb_golds    AS (SELECT COUNT(*)::int AS cnt FROM payouts WHERE user_id=$1 AND position=1),
       fb_silvers  AS (SELECT COUNT(*)::int AS cnt FROM payouts WHERE user_id=$1 AND position=2),
       fb_bronzes  AS (SELECT COUNT(*)::int AS cnt FROM payouts WHERE user_id=$1 AND position=3),
       earnings    AS (
         SELECT COALESCE(SUM(amount), 0)::numeric AS total
         FROM payouts
         WHERE user_id=$1 AND status='paid'
       ),
       total_entered AS (SELECT COUNT(*)::int AS cnt FROM entries WHERE user_id=$1),
       total_played  AS (
         SELECT COUNT(*)::int AS cnt
         FROM entries e
         JOIN tournaments t ON t.id=e.tournament_id
         WHERE e.user_id=$1 AND t.status='completed' AND e.gross_score IS NOT NULL
       ),
       best_score AS (
         SELECT MIN(e.gross_score) AS score
         FROM entries e
         JOIN tournaments t ON t.id = e.tournament_id
         WHERE e.user_id = $1 AND e.gross_score IS NOT NULL AND t.status = 'completed'
       )
       SELECT
         (SELECT cnt FROM ind_golds)   + (SELECT cnt FROM fb_golds)   AS golds,
         (SELECT cnt FROM ind_silvers) + (SELECT cnt FROM fb_silvers) AS silvers,
         (SELECT cnt FROM ind_bronzes) + (SELECT cnt FROM fb_bronzes) AS bronzes,
         (SELECT total FROM earnings)                                  AS career_earnings,
         (SELECT cnt FROM total_entered)                               AS tournaments_entered,
         (SELECT cnt FROM total_played)                                AS tournaments_played,
         (SELECT score FROM best_score)                                AS best_score`,
      [userId]
    );
    res.json({ stats: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
}

module.exports = { signup, login, getMe, updateMe, getMyStats };

const db = require('../config/database');

// GET /api/users/search?q=...
async function searchUsers(req, res) {
  const q = (req.query.q || '').trim();
  if (q.length < 2) return res.json({ users: [] });

  try {
    const { rows } = await db.query(
      `SELECT id, name, handicap, city, created_at
       FROM users
       WHERE name ILIKE $1 OR email ILIKE $1
       ORDER BY name ASC
       LIMIT 20`,
      [`%${q}%`]
    );
    res.json({ users: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to search users' });
  }
}

// GET /api/users/leaderboard?city=...
async function globalLeaderboard(req, res) {
  const city = (req.query.city || '').trim();
  const params = [];
  const cityFilter = city ? (params.push(city), `WHERE u.city ILIKE $${params.length}`) : '';

  try {
    const { rows } = await db.query(
      `SELECT
         u.id, u.name, u.handicap, u.city,
         COALESCE(SUM(p.amount), 0)::float                                AS career_earnings,
         COALESCE(AVG(NULLIF(e.net_score, 0)), 0)::float                  AS avg_net_score,
         COUNT(DISTINCT CASE WHEN e.gross_score > 0 THEN e.id END)::int   AS rounds_played,
         COUNT(DISTINCT CASE WHEN p.position = 1 THEN p.id END)::int      AS golds
       FROM users u
       LEFT JOIN entries e ON e.user_id = u.id
       LEFT JOIN payouts p ON p.user_id = u.id
       ${cityFilter}
       GROUP BY u.id
       ORDER BY career_earnings DESC, rounds_played DESC
       LIMIT 100`,
      params
    );
    res.json({ leaderboard: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
}

// GET /api/users/:id
async function getUserProfile(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT id, name, handicap, city, created_at FROM users WHERE id = $1`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    res.json({ user: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
}

// GET /api/users/:id/stats
async function getUserStats(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT
         COUNT(DISTINCT CASE WHEN e.gross_score > 0 THEN e.id END)::int      AS rounds_played,
         COALESCE(AVG(NULLIF(e.net_score, 0)), 0)::float                     AS avg_net_score,
         MIN(NULLIF(e.gross_score, 0))::int                                  AS best_gross,
         COALESCE(SUM(p.amount), 0)::float                                   AS career_earnings,
         COUNT(DISTINCT CASE WHEN p.position = 1 THEN p.id END)::int         AS golds,
         COUNT(DISTINCT CASE WHEN p.position = 2 THEN p.id END)::int         AS silvers,
         COUNT(DISTINCT CASE WHEN p.position = 3 THEN p.id END)::int         AS bronzes
       FROM users u
       LEFT JOIN entries e ON e.user_id = u.id
       LEFT JOIN payouts p ON p.user_id = u.id
       WHERE u.id = $1
       GROUP BY u.id`,
      [id]
    );
    res.json({ stats: rows[0] || {
      rounds_played: 0, avg_net_score: 0, best_gross: null,
      career_earnings: 0, golds: 0, silvers: 0, bronzes: 0,
    }});
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch user stats' });
  }
}

module.exports = { searchUsers, globalLeaderboard, getUserProfile, getUserStats };

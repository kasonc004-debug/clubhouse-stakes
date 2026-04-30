const db = require('../config/database');

// GET /api/tournaments
async function listTournaments(req, res) {
  const { city, status, format } = req.query;
  const conditions = [];
  const values     = [];
  let   idx        = 1;

  if (city)   { conditions.push(`t.city ILIKE $${idx++}`);   values.push(`%${city}%`); }
  if (status) { conditions.push(`t.status = $${idx++}`);     values.push(status); }
  if (format) { conditions.push(`t.format = $${idx++}`);     values.push(format); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         COUNT(DISTINCT e.user_id)::int                          AS player_count,
         CASE
           WHEN t.fee_per = 'team' THEN
             COUNT(DISTINCT tm_grp.team_id)::int * t.sign_up_fee
           ELSE
             COUNT(DISTINCT e.user_id)::int  * t.sign_up_fee
         END                                                     AS purse
       FROM tournaments t
       LEFT JOIN entries e ON e.tournament_id = t.id AND e.payment_status = 'paid'
       LEFT JOIN (SELECT DISTINCT team_id FROM entries WHERE team_id IS NOT NULL) tm_grp
         ON tm_grp.team_id IN (SELECT id FROM teams WHERE tournament_id = t.id)
       ${where}
       GROUP BY t.id
       ORDER BY t.date ASC`,
      values
    );
    res.json({ tournaments: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch tournaments' });
  }
}

// GET /api/tournaments/:id
async function getTournament(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         COUNT(DISTINCT e.user_id)::int          AS player_count,
         CASE
           WHEN t.fee_per = 'team' THEN
             (SELECT COUNT(DISTINCT tm2.team_id) FROM team_members tm2
              JOIN teams t2 ON t2.id = tm2.team_id WHERE t2.tournament_id = t.id)::int * t.sign_up_fee
           ELSE
             COUNT(DISTINCT e.user_id)::int * t.sign_up_fee
         END                                     AS purse
       FROM tournaments t
       LEFT JOIN entries e ON e.tournament_id = t.id AND e.payment_status = 'paid'
       WHERE t.id = $1
       GROUP BY t.id`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Tournament not found' });
    res.json({ tournament: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch tournament' });
  }
}

// POST /api/tournaments/:id/join
async function joinTournament(req, res) {
  const { id }  = req.params;
  const userId  = req.user.id;

  try {
    // Check tournament exists and has capacity
    const { rows: tRows } = await db.query(
      `SELECT t.*, COUNT(e.id)::int AS entry_count
       FROM tournaments t
       LEFT JOIN entries e ON e.tournament_id = t.id
       WHERE t.id = $1
       GROUP BY t.id`,
      [id]
    );
    if (!tRows.length)              return res.status(404).json({ error: 'Tournament not found' });
    const tournament = tRows[0];
    if (tournament.status !== 'upcoming')
      return res.status(400).json({ error: 'Tournament is no longer open for registration' });
    if (tournament.entry_count >= tournament.max_players)
      return res.status(400).json({ error: 'Tournament is full' });

    // Check duplicate
    const dup = await db.query(
      'SELECT id FROM entries WHERE user_id = $1 AND tournament_id = $2',
      [userId, id]
    );
    if (dup.rows.length) return res.status(409).json({ error: 'Already entered this tournament' });

    const { rows } = await db.query(
      `INSERT INTO entries (user_id, tournament_id, payment_status)
       VALUES ($1, $2, 'pending')
       RETURNING *`,
      [userId, id]
    );
    res.status(201).json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to join tournament' });
  }
}

// GET /api/tournaments/:id/participants
async function getParticipants(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT u.id, u.name, u.handicap, u.city,
              e.id AS entry_id, e.gross_score, e.net_score,
              e.payment_status, e.team_id
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.tournament_id = $1
       ORDER BY u.name ASC`,
      [id]
    );
    res.json({ participants: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch participants' });
  }
}

module.exports = { listTournaments, getTournament, joinTournament, getParticipants };

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
       LEFT JOIN entries e ON e.tournament_id = t.id
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
  const userId = req.user?.id || null;
  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         ch.slug AS clubhouse_slug,
         ch.name AS clubhouse_name,
         COUNT(DISTINCT e.user_id)::int AS player_count,
         CASE
           WHEN t.fee_per = 'team' THEN
             (SELECT COUNT(DISTINCT tm2.team_id) FROM team_members tm2
              JOIN teams t2 ON t2.id = tm2.team_id WHERE t2.tournament_id = t.id)::int * t.sign_up_fee
           ELSE
             COUNT(DISTINCT e.user_id)::int * t.sign_up_fee
         END AS purse,
         COUNT(DISTINCT CASE WHEN e.skins_entry = TRUE THEN e.user_id END)::int AS skins_count,
         COUNT(DISTINCT CASE WHEN e.skins_entry = TRUE THEN e.user_id END)::int * t.skins_fee AS skins_pot,
         (SELECT skins_entry FROM entries WHERE user_id = $2 AND tournament_id = t.id LIMIT 1) AS my_skins_entry,
         (SELECT id FROM entries WHERE user_id = $2 AND tournament_id = t.id LIMIT 1) AS my_entry_id,
         (SELECT payment_status FROM entries WHERE user_id = $2 AND tournament_id = t.id LIMIT 1) AS my_payment_status,
         (SELECT skins_payment_status FROM entries WHERE user_id = $2 AND tournament_id = t.id LIMIT 1) AS my_skins_payment_status
       FROM tournaments t
       LEFT JOIN clubhouses ch ON ch.id = t.clubhouse_id
       LEFT JOIN entries e ON e.tournament_id = t.id
       WHERE t.id = $1
       GROUP BY t.id, ch.slug, ch.name`,
      [id, userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Tournament not found' });
    res.json({ tournament: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch tournament' });
  }
}

// POST /api/tournaments/:id/skins
async function joinSkins(req, res) {
  const { id } = req.params;
  const userId = req.user.id;
  try {
    const { rows: entryRows } = await db.query(
      'SELECT id, skins_entry FROM entries WHERE user_id = $1 AND tournament_id = $2',
      [userId, id]
    );
    if (!entryRows.length)
      return res.status(400).json({ error: 'You must be registered for this tournament to enter skins' });
    if (entryRows[0].skins_entry)
      return res.status(409).json({ error: 'Already entered skins for this tournament' });

    const { rows: tRows } = await db.query(
      'SELECT skins_fee FROM tournaments WHERE id = $1', [id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    if (!tRows[0].skins_fee || tRows[0].skins_fee <= 0)
      return res.status(400).json({ error: 'This tournament does not have a skins game' });

    await db.query(
      'UPDATE entries SET skins_entry = TRUE WHERE user_id = $1 AND tournament_id = $2',
      [userId, id]
    );
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to enter skins game' });
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
    if (tournament.format === 'fourball' || tournament.format === 'scramble')
      return res.status(400).json({ error: 'This tournament is team-based — register through the team flow.' });
    if (tournament.entry_count >= tournament.max_players)
      return res.status(400).json({ error: 'Tournament is full' });

    // Check duplicate
    const dup = await db.query(
      'SELECT id FROM entries WHERE user_id = $1 AND tournament_id = $2',
      [userId, id]
    );
    if (dup.rows.length) return res.status(409).json({ error: 'Already entered this tournament' });

    // Pay-at-course: entry is reserved now, money is collected in person.
    // Admin flips payment_status to 'paid' once they receive it.
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
      `SELECT u.id, u.name, u.handicap, u.city, u.profile_picture_url,
              e.id AS entry_id, e.gross_score, e.net_score,
              e.payment_status, e.skins_entry, e.skins_payment_status, e.team_id
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

// GET /api/tournaments/mine
async function getMyTournaments(req, res) {
  const userId = req.user.id;
  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         e.id                   AS my_entry_id,
         e.payment_status       AS my_payment_status,
         e.skins_entry          AS my_skins_entry,
         e.skins_payment_status AS my_skins_payment_status,
         COUNT(DISTINCT e2.user_id)::int AS player_count,
         CASE
           WHEN t.fee_per = 'team' THEN
             COUNT(DISTINCT tm_grp.team_id)::int * t.sign_up_fee
           ELSE
             COUNT(DISTINCT e2.user_id)::int * t.sign_up_fee
         END AS purse
       FROM entries e
       JOIN tournaments t ON t.id = e.tournament_id
       LEFT JOIN entries e2 ON e2.tournament_id = t.id
       LEFT JOIN (SELECT DISTINCT team_id FROM entries WHERE team_id IS NOT NULL) tm_grp
         ON tm_grp.team_id IN (SELECT id FROM teams WHERE tournament_id = t.id)
       WHERE e.user_id = $1
       GROUP BY t.id, e.id, e.payment_status, e.skins_entry, e.skins_payment_status
       ORDER BY t.date ASC`,
      [userId]
    );
    res.json({ tournaments: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch your tournaments' });
  }
}

module.exports = { listTournaments, getTournament, joinTournament, getParticipants, getMyTournaments, joinSkins };

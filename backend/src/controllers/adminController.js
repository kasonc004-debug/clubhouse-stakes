const db = require('../config/database');
const { validationResult } = require('express-validator');

// POST /api/admin/tournaments
async function createTournament(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const {
    name, city, date, format, sign_up_fee,
    max_players, fee_per = 'player', course_name, description,
  } = req.body;

  try {
    const { rows } = await db.query(
      `INSERT INTO tournaments
         (name, city, date, format, sign_up_fee, max_players, fee_per, course_name, description, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [name, city, date, format, sign_up_fee, max_players, fee_per, course_name, description, req.user.id]
    );
    res.status(201).json({ tournament: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create tournament' });
  }
}

// PATCH /api/admin/tournaments/:id
async function updateTournament(req, res) {
  const { id } = req.params;
  const fields = ['name', 'city', 'date', 'format', 'sign_up_fee', 'max_players', 'fee_per', 'status', 'course_name', 'description', 'skins_fee'];
  const updates = [];
  const values  = [];
  let idx = 1;

  fields.forEach(f => {
    if (req.body[f] !== undefined) {
      updates.push(`${f} = $${idx++}`);
      values.push(req.body[f]);
    }
  });

  if (!updates.length) return res.status(422).json({ error: 'No fields to update' });
  values.push(id);

  try {
    const { rows } = await db.query(
      `UPDATE tournaments SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );
    if (!rows.length) return res.status(404).json({ error: 'Tournament not found' });
    res.json({ tournament: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update tournament' });
  }
}

// GET /api/admin/tournaments/:id/financials
async function getFinancials(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(`
      SELECT
        t.id, t.name, t.sign_up_fee, t.fee_per, t.skins_fee,
        t.house_cut_pct, t.payout_places, t.status, t.max_players,
        COUNT(DISTINCT e.user_id)::int                                                  AS player_count,
        COUNT(DISTINCT e.user_id)::int * t.sign_up_fee                                  AS total_collected,
        COUNT(DISTINCT CASE WHEN e.skins_entry = TRUE THEN e.user_id END)::int          AS skins_count,
        COUNT(DISTINCT CASE WHEN e.skins_entry = TRUE THEN e.user_id END)::int * t.skins_fee AS skins_total,
        ROUND(COUNT(DISTINCT e.user_id)::numeric * t.sign_up_fee * (t.house_cut_pct / 100.0), 2) AS house_cut_amount,
        ROUND(COUNT(DISTINCT e.user_id)::numeric * t.sign_up_fee * (1 - t.house_cut_pct / 100.0), 2) AS prize_pool
      FROM tournaments t
      LEFT JOIN entries e ON e.tournament_id = t.id AND e.payment_status = 'paid'
      WHERE t.id = $1
      GROUP BY t.id
    `, [id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json({ financials: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch financials' });
  }
}

// PATCH /api/admin/tournaments/:id/financials
async function updateFinancials(req, res) {
  const { id } = req.params;
  const { house_cut_pct, payout_places, skins_fee } = req.body;
  const updates = [];
  const values  = [];
  let idx = 1;

  if (house_cut_pct !== undefined) { updates.push(`house_cut_pct = $${idx++}`); values.push(house_cut_pct); }
  if (skins_fee     !== undefined) { updates.push(`skins_fee = $${idx++}`);     values.push(skins_fee); }
  if (payout_places !== undefined) { updates.push(`payout_places = $${idx++}`); values.push(JSON.stringify(payout_places)); }

  if (!updates.length) return res.status(422).json({ error: 'No fields provided' });
  values.push(id);

  try {
    const { rows } = await db.query(
      `UPDATE tournaments SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json({ tournament: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update financials' });
  }
}

// GET /api/admin/tournaments/:id/participants
async function adminGetParticipants(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT u.id, u.name, u.email, u.handicap,
              e.id AS entry_id, e.gross_score, e.net_score,
              e.hole_scores, e.payment_status, e.team_id
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.tournament_id = $1
       ORDER BY e.net_score ASC NULLS LAST`,
      [id]
    );
    res.json({ participants: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch participants' });
  }
}

// PATCH /api/admin/tournaments/:id/scores/:entryId
async function adminUpdateScore(req, res) {
  const { id, entryId } = req.params;
  const { hole_scores } = req.body;

  if (!Array.isArray(hole_scores) || hole_scores.length !== 18)
    return res.status(422).json({ error: 'hole_scores must be an array of 18 integers' });

  try {
    const { rows: eRows } = await db.query(
      `SELECT e.id, u.handicap
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.id = $1 AND e.tournament_id = $2`,
      [entryId, id]
    );
    if (!eRows.length) return res.status(404).json({ error: 'Entry not found' });

    const gross = hole_scores.reduce((a, b) => a + b, 0);
    const net   = parseFloat((gross - eRows[0].handicap).toFixed(1));

    const { rows } = await db.query(
      `UPDATE entries
       SET hole_scores = $1, gross_score = $2, net_score = $3, updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [hole_scores, gross, net, entryId]
    );
    res.json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update score' });
  }
}

module.exports = { createTournament, updateTournament, adminGetParticipants, getFinancials, updateFinancials, adminUpdateScore };

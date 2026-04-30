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
  const fields = ['name', 'city', 'date', 'format', 'sign_up_fee', 'max_players', 'fee_per', 'status', 'course_name', 'description'];
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

module.exports = { createTournament, updateTournament, adminGetParticipants };

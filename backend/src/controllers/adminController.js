const db = require('../config/database');
const { validationResult } = require('express-validator');
const { notify } = require('./notificationController');

// POST /api/admin/tournaments
async function createTournament(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const {
    name, city, date, format, sign_up_fee,
    max_players, fee_per = 'player', course_name, description,
    skins_fee = 0, rules, handicap_enabled, pars,
    yardages, tee_name, course_api_id, clubhouse_id,
  } = req.body;

  // Validate pars if provided: 18 ints in 3..7
  let parsValue = null;
  if (Array.isArray(pars)) {
    if (pars.length !== 18) return res.status(422).json({ error: 'pars must be an array of 18 integers' });
    const ok = pars.every(p => Number.isInteger(p) && p >= 3 && p <= 7);
    if (!ok) return res.status(422).json({ error: 'each par must be an integer between 3 and 7' });
    parsValue = pars;
  }

  // Validate yardages if provided: 18 non-negative ints
  let yardagesValue = null;
  if (Array.isArray(yardages)) {
    if (yardages.length !== 18) return res.status(422).json({ error: 'yardages must be an array of 18 integers' });
    const ok = yardages.every(y => Number.isInteger(y) && y >= 0 && y <= 1000);
    if (!ok) return res.status(422).json({ error: 'each yardage must be a non-negative integer' });
    yardagesValue = yardages;
  }

  try {
    const { rows } = await db.query(
      `INSERT INTO tournaments
         (name, city, date, format, sign_up_fee, max_players, fee_per,
          course_name, description, skins_fee, rules, handicap_enabled, pars,
          yardages, tee_name, course_api_id, clubhouse_id, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
       RETURNING *`,
      [name, city, date, format, sign_up_fee, max_players, fee_per,
       course_name, description, skins_fee || 0, rules || null,
       handicap_enabled !== false, parsValue,
       yardagesValue, tee_name || null, course_api_id || null,
       clubhouse_id || null, req.user.id]
    );
    const tournament = rows[0];

    // Fan out a notification to clubhouse members.
    if (tournament.clubhouse_id) {
      try {
        const { rows: ch } = await db.query(
          'SELECT name, slug FROM clubhouses WHERE id = $1',
          [tournament.clubhouse_id]
        );
        const { rows: members } = await db.query(
          `SELECT user_id FROM clubhouse_members
           WHERE clubhouse_id = $1 AND status = 'member' AND user_id <> $2`,
          [tournament.clubhouse_id, req.user.id]
        );
        if (ch.length && members.length) {
          await notify({
            userIds: members.map(m => m.user_id),
            type:    'clubhouse_tournament',
            title:   `New tournament at ${ch[0].name}`,
            body:    tournament.name,
            link:    `/tournament/${tournament.id}`,
            payload: {
              tournament_id:  tournament.id,
              clubhouse_id:   tournament.clubhouse_id,
              clubhouse_slug: ch[0].slug,
            },
          });
        }
      } catch (notifyErr) {
        console.error('clubhouse fan-out failed:', notifyErr.message);
        // Don't fail the tournament create over notification problems.
      }
    }

    res.status(201).json({ tournament });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create tournament' });
  }
}

// PATCH /api/admin/tournaments/:id
async function updateTournament(req, res) {
  const { id } = req.params;
  const fields = ['name', 'city', 'date', 'format', 'sign_up_fee', 'max_players', 'fee_per', 'status', 'course_name', 'description', 'skins_fee', 'rules', 'handicap_enabled', 'pars', 'yardages', 'tee_name', 'course_api_id', 'clubhouse_id'];
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
              e.hole_scores, e.payment_status,
              e.skins_entry, e.skins_payment_status, e.team_id
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

// PATCH /api/admin/tournaments/:id/entries/:entryId/payment
// Body: { payment_status?, skins_payment_status? }
// Lets the host mark cash collected at the course.
async function adminUpdatePayment(req, res) {
  const { id, entryId } = req.params;
  const { payment_status, skins_payment_status } = req.body || {};
  const valid = new Set(['pending', 'paid', 'refunded']);

  const updates = [];
  const values  = [];
  let idx = 1;
  if (payment_status !== undefined) {
    if (!valid.has(payment_status))
      return res.status(422).json({ error: 'Invalid payment_status' });
    updates.push(`payment_status = $${idx++}`);
    values.push(payment_status);
  }
  if (skins_payment_status !== undefined) {
    if (!valid.has(skins_payment_status))
      return res.status(422).json({ error: 'Invalid skins_payment_status' });
    updates.push(`skins_payment_status = $${idx++}`);
    values.push(skins_payment_status);
  }
  if (!updates.length) return res.status(422).json({ error: 'No fields to update' });

  values.push(entryId, id);
  try {
    const { rows } = await db.query(
      `UPDATE entries SET ${updates.join(', ')}
       WHERE id = $${idx} AND tournament_id = $${idx + 1}
       RETURNING *`,
      values
    );
    if (!rows.length) return res.status(404).json({ error: 'Entry not found' });
    res.json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update payment' });
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

// DELETE /api/admin/tournaments/:id
// Permission gate is applied at the route layer (canManageTournament).
async function deleteTournament(req, res) {
  const { id } = req.params;
  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      'SELECT id FROM tournaments WHERE id = $1', [id]
    );
    if (!rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Tournament not found' });
    }
    // payouts FK isn't CASCADE — purge them first.
    await client.query('DELETE FROM payouts WHERE tournament_id = $1', [id]);
    // entries + teams cascade automatically.
    await client.query('DELETE FROM tournaments WHERE id = $1', [id]);
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Failed to delete tournament' });
  } finally {
    client.release();
  }
}

module.exports = { createTournament, updateTournament, adminGetParticipants, getFinancials, updateFinancials, adminUpdateScore, adminUpdatePayment, deleteTournament };

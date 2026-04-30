const db = require('../config/database');

function calcNetScore(grossScore, handicap) {
  return parseFloat((grossScore - handicap).toFixed(1));
}

// POST /api/scores/submit
async function submitScore(req, res) {
  const { tournament_id, hole_scores } = req.body;
  const userId = req.user.id;

  if (!tournament_id)             return res.status(422).json({ error: 'tournament_id is required' });
  if (!Array.isArray(hole_scores) || hole_scores.length !== 18)
    return res.status(422).json({ error: 'hole_scores must be an array of 18 integers' });

  try {
    const { rows: tRows } = await db.query(
      `SELECT t.format FROM tournaments t WHERE t.id = $1`,
      [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });

    const { rows: eRows } = await db.query(
      `SELECT e.id, e.team_id, u.handicap
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.user_id = $1 AND e.tournament_id = $2`,
      [userId, tournament_id]
    );
    if (!eRows.length) return res.status(404).json({ error: 'Entry not found — register first' });

    const entry      = eRows[0];
    const grossScore = hole_scores.reduce((a, b) => a + b, 0);
    const netScore   = calcNetScore(grossScore, entry.handicap);

    const { rows } = await db.query(
      `UPDATE entries
       SET hole_scores = $1, gross_score = $2, net_score = $3, updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [hole_scores, grossScore, netScore, entry.id]
    );
    res.json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to submit score' });
  }
}

// GET /api/scores/:tournament_id/me
async function getMyScore(req, res) {
  const { tournament_id } = req.params;
  const userId = req.user.id;

  try {
    const { rows } = await db.query(
      `SELECT e.*, u.handicap
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.user_id = $1 AND e.tournament_id = $2`,
      [userId, tournament_id]
    );
    if (!rows.length) return res.status(404).json({ error: 'No entry found' });
    res.json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch score' });
  }
}

module.exports = { submitScore, getMyScore };

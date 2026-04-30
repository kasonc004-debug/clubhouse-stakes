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

// PATCH /api/scores/:tournament_id/hole
async function updateHoleScore(req, res) {
  const { tournament_id } = req.params;
  const { hole_number, score } = req.body;
  const userId = req.user.id;

  const holeNum   = parseInt(hole_number, 10);
  const holeScore = parseInt(score, 10);

  if (!holeNum || holeNum < 1 || holeNum > 18)
    return res.status(422).json({ error: 'hole_number must be 1–18' });
  if (isNaN(holeScore) || holeScore < 1 || holeScore > 20)
    return res.status(422).json({ error: 'score must be an integer 1–20' });

  try {
    const { rows: tRows } = await db.query(
      'SELECT status FROM tournaments WHERE id = $1', [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    if (tRows[0].status !== 'active')
      return res.status(400).json({ error: 'Tournament is not active' });

    const { rows: eRows } = await db.query(
      `SELECT e.id, e.hole_scores, u.handicap
       FROM entries e JOIN users u ON u.id = e.user_id
       WHERE e.user_id = $1 AND e.tournament_id = $2`,
      [userId, tournament_id]
    );
    if (!eRows.length) return res.status(404).json({ error: 'Entry not found' });

    const entry = eRows[0];
    const holes = Array.isArray(entry.hole_scores) && entry.hole_scores.length === 18
      ? [...entry.hole_scores]
      : new Array(18).fill(0);
    holes[holeNum - 1] = holeScore;

    const grossScore  = holes.reduce((a, b) => a + b, 0);
    const filledCount = holes.filter(h => h > 0).length;
    const netScore    = filledCount === 18
      ? calcNetScore(grossScore, parseFloat(entry.handicap))
      : null;

    const { rows } = await db.query(
      `UPDATE entries
         SET hole_scores = $1, gross_score = $2, net_score = $3, updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [holes, grossScore, netScore, entry.id]
    );
    res.json({ entry: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update hole score' });
  }
}

module.exports = { submitScore, getMyScore, updateHoleScore };

const db = require('../config/database');

// GET /api/leaderboard/:tournament_id
async function getLeaderboard(req, res) {
  const { tournament_id } = req.params;

  try {
    const { rows: tRows } = await db.query(
      'SELECT format FROM tournaments WHERE id = $1',
      [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    const { format } = tRows[0];

    if (format === 'individual') {
      return individualLeaderboard(res, tournament_id);
    }
    return fourballLeaderboard(res, tournament_id);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
}

async function individualLeaderboard(res, tournamentId) {
  const { rows } = await db.query(
    `SELECT
       u.id AS user_id, u.name, u.handicap,
       e.gross_score, e.net_score, e.hole_scores,
       RANK() OVER (ORDER BY e.net_score ASC NULLS LAST) AS rank
     FROM entries e
     JOIN users u ON u.id = e.user_id
     WHERE e.tournament_id = $1
       AND e.gross_score IS NOT NULL
     ORDER BY rank ASC`,
    [tournamentId]
  );
  res.json({ format: 'individual', leaderboard: rows });
}

async function fourballLeaderboard(res, tournamentId) {
  // Fetch all entries with hole scores for this tournament
  const { rows: entries } = await db.query(
    `SELECT
       e.user_id, e.team_id, e.hole_scores, e.gross_score,
       u.name, u.handicap
     FROM entries e
     JOIN users u ON u.id = e.user_id
     WHERE e.tournament_id = $1
       AND e.team_id IS NOT NULL`,
    [tournamentId]
  );

  // Fetch team names
  const { rows: teams } = await db.query(
    'SELECT id, name FROM teams WHERE tournament_id = $1',
    [tournamentId]
  );
  const teamMap = {};
  teams.forEach(t => { teamMap[t.id] = t.name; });

  // Group by team
  const teamGroups = {};
  entries.forEach(e => {
    if (!teamGroups[e.team_id]) teamGroups[e.team_id] = [];
    teamGroups[e.team_id].push(e);
  });

  const result = [];
  for (const [teamId, members] of Object.entries(teamGroups)) {
    if (members.length < 2 || members.some(m => !m.hole_scores?.length)) continue;

    // Per-hole handicap strokes (simple: full handicap / 18, rounded)
    const bestBallPerHole = Array.from({ length: 18 }, (_, h) => {
      const netScores = members.map(m => {
        const hcpPerHole = m.handicap / 18;
        return (m.hole_scores[h] || 0) - hcpPerHole;
      });
      return Math.min(...netScores);
    });

    const teamNetTotal = parseFloat(bestBallPerHole.reduce((a, b) => a + b, 0).toFixed(1));

    result.push({
      team_id:      teamId,
      team_name:    teamMap[teamId] || `${members[0].name} / ${members[1].name}`,
      players:      members.map(m => ({ user_id: m.user_id, name: m.name, handicap: m.handicap, hole_scores: m.hole_scores })),
      net_total:    teamNetTotal,
      best_ball_per_hole: bestBallPerHole,
    });
  }

  result.sort((a, b) => a.net_total - b.net_total);
  result.forEach((r, i) => { r.rank = i + 1; });

  res.json({ format: 'fourball', leaderboard: result });
}

module.exports = { getLeaderboard };

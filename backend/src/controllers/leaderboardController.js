const db = require('../config/database');

// GET /api/leaderboard/:tournament_id
async function getLeaderboard(req, res) {
  const { tournament_id } = req.params;
  try {
    const { rows: tRows } = await db.query(
      'SELECT format, status FROM tournaments WHERE id = $1',
      [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    const { format, status } = tRows[0];

    if (format === 'individual') {
      return individualLeaderboard(res, tournament_id, status);
    }
    return fourballLeaderboard(res, tournament_id, status);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
}

async function individualLeaderboard(res, tournamentId, status) {
  // Include any player who has entered at least one hole (gross_score > 0)
  // net_score is null until all 18 holes are done — rank those last
  const { rows } = await db.query(
    `SELECT
       u.id AS user_id, u.name, u.handicap,
       e.gross_score, e.net_score, e.hole_scores,
       RANK() OVER (
         ORDER BY
           CASE WHEN e.net_score IS NOT NULL THEN e.net_score ELSE 99999 END ASC,
           e.gross_score ASC NULLS LAST
       ) AS rank
     FROM entries e
     JOIN users u ON u.id = e.user_id
     WHERE e.tournament_id = $1
       AND e.gross_score > 0
     ORDER BY rank ASC`,
    [tournamentId]
  );

  // Add holes_played derived from hole_scores array
  const leaderboard = rows.map(r => ({
    ...r,
    holes_played: (r.hole_scores || []).filter(h => h > 0).length,
  }));

  res.json({ format: 'individual', status, leaderboard });
}

async function fourballLeaderboard(res, tournamentId, status) {
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

  const { rows: teams } = await db.query(
    'SELECT id, name FROM teams WHERE tournament_id = $1',
    [tournamentId]
  );
  const teamMap = {};
  teams.forEach(t => { teamMap[t.id] = t.name; });

  const teamGroups = {};
  entries.forEach(e => {
    if (!teamGroups[e.team_id]) teamGroups[e.team_id] = [];
    teamGroups[e.team_id].push(e);
  });

  const result = [];
  for (const [teamId, members] of Object.entries(teamGroups)) {
    if (members.length < 2) continue;
    const hasAnyScores = members.some(m => m.gross_score > 0);
    if (!hasAnyScores) continue;

    const holesAvailable = Math.max(...members.map(m =>
      (m.hole_scores || []).filter(h => h > 0).length
    ));

    const bestBallPerHole = Array.from({ length: 18 }, (_, h) => {
      const netScores = members.map(m => {
        const hcpPerHole = m.handicap / 18;
        return ((m.hole_scores || [])[h] || 0) - hcpPerHole;
      });
      return Math.min(...netScores);
    });

    const teamNetTotal = parseFloat(
      bestBallPerHole.slice(0, holesAvailable).reduce((a, b) => a + b, 0).toFixed(1)
    );

    result.push({
      team_id:            teamId,
      team_name:          teamMap[teamId] || `${members[0].name} / ${members[1].name}`,
      players:            members.map(m => ({
        user_id:     m.user_id,
        name:        m.name,
        handicap:    m.handicap,
        hole_scores: m.hole_scores,
      })),
      net_total:          teamNetTotal,
      holes_played:       holesAvailable,
      best_ball_per_hole: bestBallPerHole,
    });
  }

  result.sort((a, b) => a.net_total - b.net_total);
  result.forEach((r, i) => { r.rank = i + 1; });

  res.json({ format: 'fourball', status, leaderboard: result });
}

module.exports = { getLeaderboard };

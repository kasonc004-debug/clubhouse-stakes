const db = require('../config/database');

// Stroke index per hole (1–18). Value = difficulty rank (1 = hardest, 18 = easiest).
// Player receives a stroke on holes where their course handicap >= the stroke index.
const STROKE_INDEX = [1, 10, 17, 2, 11, 16, 3, 12, 15, 4, 13, 14, 5, 9, 18, 6, 8, 7];

function strokesOnHole(handicap, holeStrokeIndex) {
  const hcp   = Math.round(parseFloat(handicap) || 0);
  const base  = Math.floor(hcp / 18);
  const extra = hcp % 18;
  return base + (holeStrokeIndex <= extra ? 1 : 0);
}

function computeSkins(skinsPlayers, skinsPotTotal) {
  const holeValue       = skinsPotTotal / 18;
  let   definiteCarry   = 0;   // carryover from definitively decided holes
  const holesResult     = [];
  const skinsWon        = {};  // userId → { name, holesWon, totalAmount }

  for (let h = 0; h < 18; h++) {
    const si         = STROKE_INDEX[h];
    const currentPot = parseFloat((holeValue * (1 + definiteCarry)).toFixed(2));

    const holeScores = skinsPlayers
      .filter(p => (p.holeScores[h] || 0) > 0)
      .map(p => {
        const gross   = p.holeScores[h];
        const strokes = strokesOnHole(p.handicap, si);
        return { userId: p.userId, name: p.name, gross, strokes, net: gross - strokes };
      });

    const playersIn    = holeScores.length;
    const totalPlayers = skinsPlayers.length;

    if (playersIn === 0) {
      holesResult.push({ hole: h + 1, pot: currentPot, status: 'pending', carryIn: definiteCarry, playersIn, totalPlayers });
      continue;
    }

    const minNet  = Math.min(...holeScores.map(s => s.net));
    const leaders = holeScores.filter(s => s.net === minNet);

    if (playersIn < totalPlayers) {
      // Not all skins players have scored yet — show provisional leader
      holesResult.push({
        hole: h + 1, pot: currentPot,
        status:      leaders.length === 1 ? 'leading' : 'provisional_tied',
        leader:      leaders.length === 1 ? { userId: leaders[0].userId, name: leaders[0].name, netScore: minNet } : null,
        tiedPlayers: leaders.length > 1   ? leaders.map(l => ({ userId: l.userId, name: l.name, netScore: minNet })) : [],
        carryIn: definiteCarry, playersIn, totalPlayers,
      });
      // Provisional holes don't advance the definite carry counter
    } else if (leaders.length === 1) {
      // All scored, outright winner
      const w = leaders[0];
      holesResult.push({ hole: h + 1, pot: currentPot, status: 'won', winner: { userId: w.userId, name: w.name, netScore: minNet }, carryIn: definiteCarry, playersIn, totalPlayers });
      if (!skinsWon[w.userId]) skinsWon[w.userId] = { name: w.name, holesWon: [], totalAmount: 0 };
      skinsWon[w.userId].holesWon.push(h + 1);
      skinsWon[w.userId].totalAmount = parseFloat((skinsWon[w.userId].totalAmount + currentPot).toFixed(2));
      definiteCarry = 0;
    } else {
      // All scored, tied — carry over
      holesResult.push({
        hole: h + 1, pot: currentPot, status: 'tied',
        tiedPlayers: leaders.map(l => ({ userId: l.userId, name: l.name, netScore: minNet })),
        carryIn: definiteCarry, playersIn, totalPlayers,
      });
      definiteCarry++;
    }
  }

  const allComplete  = skinsPlayers.every(p => p.holeScores.filter(h => h > 0).length === 18);
  const totalAwarded = Object.values(skinsWon).reduce((s, w) => s + w.totalAmount, 0);

  return {
    holes: holesResult,
    summary: {
      totalPot:         skinsPotTotal,
      holeValue:        parseFloat(holeValue.toFixed(2)),
      skinsWon:         Object.entries(skinsWon)
                          .map(([userId, d]) => ({ userId, name: d.name, holesWon: d.holesWon, amount: d.totalAmount }))
                          .sort((a, b) => b.amount - a.amount),
      isComplete:       allComplete,
      carryoverHoles:   definiteCarry,  // unresolved at end of round
      totalAwarded:     parseFloat(totalAwarded.toFixed(2)),
    },
  };
}

// GET /api/leaderboard/:tournament_id/skins
async function getSkinsLeaderboard(req, res) {
  const { tournament_id } = req.params;
  try {
    const { rows: tRows } = await db.query(
      'SELECT status, skins_fee FROM tournaments WHERE id = $1',
      [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    const { status, skins_fee } = tRows[0];
    if (!skins_fee || parseFloat(skins_fee) <= 0)
      return res.status(404).json({ error: 'This tournament has no skins game' });

    const { rows: entries } = await db.query(
      `SELECT e.hole_scores, u.id AS user_id, u.name, u.handicap
       FROM entries e
       JOIN users u ON u.id = e.user_id
       WHERE e.tournament_id = $1 AND e.skins_entry = TRUE
       ORDER BY u.name ASC`,
      [tournament_id]
    );

    const fee      = parseFloat(skins_fee);
    const skinsPot = parseFloat((entries.length * fee).toFixed(2));

    if (!entries.length) {
      return res.json({ status, skinsFee: fee, skinsPot: 0, players: [], holes: [], summary: null });
    }

    const skinsPlayers = entries.map(e => ({
      userId:     e.user_id,
      name:       e.name,
      handicap:   parseFloat(e.handicap) || 0,
      holeScores: Array.isArray(e.hole_scores) && e.hole_scores.length === 18
                    ? e.hole_scores.map(Number)
                    : new Array(18).fill(0),
    }));

    const { holes, summary } = computeSkins(skinsPlayers, skinsPot);

    res.json({
      status,
      skinsFee:  fee,
      skinsPot,
      players:   skinsPlayers.map(p => ({ userId: p.userId, name: p.name, handicap: p.handicap })),
      holes,
      summary,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch skins leaderboard' });
  }
}

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

module.exports = { getLeaderboard, getSkinsLeaderboard };

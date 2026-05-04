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
      'SELECT format, status, handicap_enabled, pars, yardages FROM tournaments WHERE id = $1',
      [tournament_id]
    );
    if (!tRows.length) return res.status(404).json({ error: 'Tournament not found' });
    const { format, status, pars, yardages } = tRows[0];
    const handicapEnabled = tRows[0].handicap_enabled !== false;

    if (format === 'individual') {
      return individualLeaderboard(res, tournament_id, status, handicapEnabled, pars, yardages);
    }
    if (format === 'scramble') {
      return scrambleLeaderboard(res, tournament_id, status, handicapEnabled, pars, yardages);
    }
    return fourballLeaderboard(res, tournament_id, status, handicapEnabled, pars, yardages);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
}

async function individualLeaderboard(res, tournamentId, status, handicapEnabled, pars, yardages) {
  // Rank by net when handicap mode is on, gross otherwise.
  // Net is null until all 18 holes are entered — rank those by gross-as-tiebreak.
  const orderBy = handicapEnabled
    ? `CASE WHEN e.net_score IS NOT NULL THEN e.net_score ELSE 99999 END ASC,
       e.gross_score ASC NULLS LAST`
    : `e.gross_score ASC NULLS LAST`;

  const { rows } = await db.query(
    `SELECT
       u.id AS user_id, u.name, u.handicap,
       e.gross_score, e.net_score, e.hole_scores,
       RANK() OVER (ORDER BY ${orderBy}) AS rank
     FROM entries e
     JOIN users u ON u.id = e.user_id
     WHERE e.tournament_id = $1
       AND e.gross_score > 0
     ORDER BY rank ASC`,
    [tournamentId]
  );

  const leaderboard = rows.map(r => ({
    ...r,
    // Hide net when handicap mode disabled.
    net_score: handicapEnabled ? r.net_score : null,
    holes_played: (r.hole_scores || []).filter(h => h > 0).length,
  }));

  res.json({ format: 'individual', status, handicap_enabled: handicapEnabled, pars, yardages, leaderboard });
}

async function fourballLeaderboard(res, tournamentId, status, handicapEnabled, pars, yardages) {
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
      const scores = members.map(m => {
        const raw = (m.hole_scores || [])[h] || 0;
        if (!handicapEnabled) return raw === 0 ? Infinity : raw;
        const hcpPerHole = m.handicap / 18;
        return raw === 0 ? Infinity : raw - hcpPerHole;
      });
      const min = Math.min(...scores);
      return min === Infinity ? 0 : min;
    });

    const teamTotal = parseFloat(
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
      net_total:          teamTotal,
      holes_played:       holesAvailable,
      best_ball_per_hole: bestBallPerHole,
    });
  }

  result.sort((a, b) => a.net_total - b.net_total);
  result.forEach((r, i) => { r.rank = i + 1; });

  res.json({ format: 'fourball', status, handicap_enabled: handicapEnabled, pars, yardages, leaderboard: result });
}

// Scramble team handicap allowance.
// Only 2-man scramble is handicapped (35% low / 15% high).
// 3- and 4-player scrambles always play gross — handicaps don't apply.
function scrambleTeamHandicap(sortedAsc) {
  if (sortedAsc.length !== 2) return 0;
  const total = sortedAsc[0] * 0.35 + sortedAsc[1] * 0.15;
  return parseFloat(total.toFixed(1));
}

async function scrambleLeaderboard(res, tournamentId, status, handicapEnabled, pars, yardages) {
  // For scramble we keep one team scorecard, owned by the designated scorer.
  // Pull every member's entry so we can compute the team handicap, but the
  // hole_scores we display come from the scorer's entry only.
  const { rows: rows } = await db.query(
    `SELECT
       e.user_id, e.team_id, e.hole_scores, e.gross_score,
       u.name, u.handicap,
       tm.name AS team_name, tm.scorer_id
     FROM entries e
     JOIN users u  ON u.id = e.user_id
     JOIN teams tm ON tm.id = e.team_id
     WHERE e.tournament_id = $1 AND e.team_id IS NOT NULL`,
    [tournamentId]
  );

  const teams = new Map();
  for (const r of rows) {
    if (!teams.has(r.team_id)) {
      teams.set(r.team_id, {
        team_id:    r.team_id,
        team_name:  r.team_name,
        scorer_id:  r.scorer_id,
        members:    [],
        scorerHoleScores: null,
      });
    }
    const team = teams.get(r.team_id);
    team.members.push({
      user_id:  r.user_id,
      name:     r.name,
      handicap: parseFloat(r.handicap) || 0,
    });
    if (r.user_id === r.scorer_id) {
      team.scorerHoleScores = Array.isArray(r.hole_scores) ? r.hole_scores : [];
    }
  }

  const result = [];
  for (const team of teams.values()) {
    const holes = team.scorerHoleScores || [];
    const filled = holes.filter(h => h > 0).length;
    if (filled === 0) continue;

    const gross = holes.reduce((a, b) => a + (b || 0), 0);
    const sortedHcps = team.members.map(m => m.handicap).sort((a, b) => a - b);
    const teamHandicap = handicapEnabled ? scrambleTeamHandicap(sortedHcps) : 0;
    const netTotal = parseFloat((gross - teamHandicap).toFixed(1));

    result.push({
      team_id:            team.team_id,
      team_name:          team.team_name ||
                            team.members.map(m => m.name).join(' / '),
      players:            team.members.map(m => ({
                            user_id:     m.user_id,
                            name:        m.name,
                            handicap:    m.handicap,
                            hole_scores: [],
                          })),
      net_total:          netTotal,
      gross_total:        gross,
      team_handicap:      teamHandicap,
      holes_played:       filled,
      // Reuse the fourball field name so the mobile model can decode either.
      best_ball_per_hole: holes.map(h => h || 0),
    });
  }

  result.sort((a, b) => a.net_total - b.net_total);
  result.forEach((r, i) => { r.rank = i + 1; });

  res.json({
    format:           'scramble',
    status,
    handicap_enabled: handicapEnabled,
    pars,
    yardages,
    leaderboard:      result,
  });
}

// GET /api/leaderboard/best-rounds?limit=50
// Record book — top individual rounds + top fourball team rounds across
// all completed tournaments.
async function getBestRounds(req, res) {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);

  try {
    // ── Individual: lowest gross score in any completed individual tournament
    const { rows: indRows } = await db.query(
      `SELECT
         u.id   AS user_id,
         u.name,
         u.profile_picture_url,
         u.handicap,
         e.gross_score,
         e.net_score,
         t.id   AS tournament_id,
         t.name AS tournament_name,
         t.course_name,
         t.date
       FROM entries e
       JOIN tournaments t ON t.id = e.tournament_id
       JOIN users u       ON u.id = e.user_id
       WHERE t.format = 'individual'
         AND t.status = 'completed'
         AND e.gross_score IS NOT NULL
         AND COALESCE(array_length(e.hole_scores, 1), 0) = 18
       ORDER BY e.gross_score ASC, e.net_score ASC NULLS LAST
       LIMIT $1`,
      [limit]
    );

    // ── Fourball: best team rounds. Compute net_total per team in JS so we
    // can reuse the same best-ball algorithm as the live leaderboard.
    const { rows: fbRows } = await db.query(
      `SELECT
         e.team_id,
         e.user_id,
         e.hole_scores,
         e.gross_score,
         u.name,
         u.handicap,
         tm.name AS team_name,
         tr.id   AS tournament_id,
         tr.name AS tournament_name,
         tr.course_name,
         tr.date,
         tr.handicap_enabled
       FROM entries e
       JOIN tournaments tr ON tr.id = e.tournament_id
       JOIN users u        ON u.id  = e.user_id
       JOIN teams tm       ON tm.id = e.team_id
       WHERE tr.format = 'fourball'
         AND tr.status = 'completed'
         AND e.team_id IS NOT NULL
         AND e.gross_score IS NOT NULL`,
    );

    const teamMap = new Map();
    for (const row of fbRows) {
      const key = `${row.tournament_id}::${row.team_id}`;
      if (!teamMap.has(key)) {
        teamMap.set(key, {
          tournament_id:    row.tournament_id,
          tournament_name:  row.tournament_name,
          course_name:      row.course_name,
          date:             row.date,
          team_id:          row.team_id,
          team_name:        row.team_name,
          handicap_enabled: row.handicap_enabled !== false,
          players:          [],
        });
      }
      teamMap.get(key).players.push({
        user_id:     row.user_id,
        name:        row.name,
        handicap:    parseFloat(row.handicap) || 0,
        hole_scores: Array.isArray(row.hole_scores) ? row.hole_scores : [],
      });
    }

    const fbResults = [];
    for (const team of teamMap.values()) {
      if (team.players.length < 2) continue;
      const allComplete = team.players.every(p =>
        (p.hole_scores || []).filter(h => h > 0).length === 18);
      if (!allComplete) continue;

      const bestBallPerHole = Array.from({ length: 18 }, (_, h) => {
        const scores = team.players.map(p => {
          const raw = (p.hole_scores || [])[h] || 0;
          if (!team.handicap_enabled) return raw;
          return raw - (p.handicap / 18);
        });
        return Math.min(...scores);
      });
      const netTotal = parseFloat(
        bestBallPerHole.reduce((a, b) => a + b, 0).toFixed(1)
      );

      fbResults.push({
        tournament_id:   team.tournament_id,
        tournament_name: team.tournament_name,
        course_name:     team.course_name,
        date:            team.date,
        team_id:         team.team_id,
        team_name:       team.team_name ||
                          team.players.map(p => p.name).join(' / '),
        net_total:       netTotal,
        players:         team.players.map(p => ({
                            user_id:  p.user_id,
                            name:     p.name,
                            handicap: p.handicap,
                          })),
      });
    }

    fbResults.sort((a, b) => a.net_total - b.net_total);

    res.json({
      individual: indRows,
      fourball:   fbResults.slice(0, limit),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch best rounds' });
  }
}

module.exports = { getLeaderboard, getSkinsLeaderboard, getBestRounds };

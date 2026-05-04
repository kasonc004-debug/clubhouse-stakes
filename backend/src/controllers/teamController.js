const db = require('../config/database');

// Max team size per format. Scramble allows 2–4 members; fourball is fixed at 2.
const MAX_TEAM_SIZE = { fourball: 2, scramble: 4 };
function isTeamFormat(format) {
  return format === 'fourball' || format === 'scramble';
}

// POST /api/teams/create
// body: { tournament_id, name?, partner_id? }
// When partner_id is supplied both players are registered atomically.
async function createTeam(req, res) {
  const { tournament_id, name, partner_id } = req.body;
  const userId = req.user.id;

  if (!tournament_id) return res.status(422).json({ error: 'tournament_id is required' });
  if (partner_id && partner_id === userId)
    return res.status(422).json({ error: 'You cannot add yourself as a partner' });

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Validate tournament
    const { rows: tRows } = await client.query(
      `SELECT t.*, COUNT(e.id)::int AS entry_count
       FROM tournaments t
       LEFT JOIN entries e ON e.tournament_id = t.id
       WHERE t.id = $1 GROUP BY t.id`,
      [tournament_id]
    );
    if (!tRows.length)                   throw { status: 404, message: 'Tournament not found' };
    const t = tRows[0];
    if (!isTeamFormat(t.format))         throw { status: 400, message: 'Teams only available in fourball / scramble' };
    if (t.status !== 'upcoming')         throw { status: 400, message: 'Tournament is not open' };

    // Check capacity — need room for both players when partner is provided
    const spotsNeeded = partner_id ? 2 : 1;
    if (t.entry_count + spotsNeeded > t.max_players)
      throw { status: 400, message: 'Not enough spots left in the tournament' };

    // Check creator not already entered
    const creatorCheck = await client.query(
      `SELECT id FROM entries WHERE user_id = $1 AND tournament_id = $2`,
      [userId, tournament_id]
    );
    if (creatorCheck.rows.length) throw { status: 409, message: 'You are already entered in this tournament' };

    // Validate and check partner when provided
    if (partner_id) {
      const partnerUser = await client.query(
        `SELECT id, name FROM users WHERE id = $1`, [partner_id]
      );
      if (!partnerUser.rows.length) throw { status: 404, message: 'Partner account not found' };

      const partnerEntry = await client.query(
        `SELECT id FROM entries WHERE user_id = $1 AND tournament_id = $2`,
        [partner_id, tournament_id]
      );
      if (partnerEntry.rows.length)
        throw { status: 409, message: `${partnerUser.rows[0].name} is already entered in this tournament` };
    }

    // Create team — creator is designated scorer by default
    const { rows: teamRows } = await client.query(
      `INSERT INTO teams (tournament_id, name, created_by, scorer_id) VALUES ($1, $2, $3, $3) RETURNING *`,
      [tournament_id, name || null, userId]
    );
    const team = teamRows[0];

    // Register creator
    await client.query(
      `INSERT INTO team_members (team_id, user_id) VALUES ($1, $2)`, [team.id, userId]
    );
    await client.query(
      `INSERT INTO entries (user_id, tournament_id, team_id, payment_status) VALUES ($1, $2, $3, 'pending')`,
      [userId, tournament_id, team.id]
    );

    // Register partner atomically when provided
    if (partner_id) {
      await client.query(
        `INSERT INTO team_members (team_id, user_id) VALUES ($1, $2)`, [team.id, partner_id]
      );
      await client.query(
        `INSERT INTO entries (user_id, tournament_id, team_id, payment_status) VALUES ($1, $2, $3, 'pending')`,
        [partner_id, tournament_id, team.id]
      );
    }

    await client.query('COMMIT');

    // Return team with member details
    const { rows: fullTeam } = await db.query(
      `SELECT t.id, t.tournament_id, t.name, t.created_at, t.scorer_id,
              COUNT(tm.id)::int AS member_count,
              json_agg(json_build_object('id', u.id, 'name', u.name, 'handicap', u.handicap)
                ORDER BY tm.created_at) AS members
       FROM teams t
       LEFT JOIN team_members tm ON tm.team_id = t.id
       LEFT JOIN users u ON u.id = tm.user_id
       WHERE t.id = $1
       GROUP BY t.id`,
      [team.id]
    );
    res.status(201).json({ team: fullTeam[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.status) return res.status(err.status).json({ error: err.message });
    console.error(err);
    res.status(500).json({ error: 'Failed to create team' });
  } finally {
    client.release();
  }
}

// POST /api/teams/:id/join
async function joinTeam(req, res) {
  const { id }  = req.params;
  const userId  = req.user.id;

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Load team with member count
    const { rows: teamRows } = await client.query(
      `SELECT t.*, COUNT(tm.id)::int AS member_count,
              tr.format, tr.status AS tournament_status,
              tr.max_players,
              (SELECT COUNT(*) FROM entries e WHERE e.tournament_id = tr.id)::int AS entry_count
       FROM teams t
       JOIN tournaments tr ON tr.id = t.tournament_id
       LEFT JOIN team_members tm ON tm.team_id = t.id
       WHERE t.id = $1
       GROUP BY t.id, tr.format, tr.status, tr.max_players`,
      [id]
    );
    if (!teamRows.length)                        throw { status: 404, message: 'Team not found' };
    const team = teamRows[0];
    if (!isTeamFormat(team.format))              throw { status: 400, message: 'Teams only in fourball / scramble' };
    if (team.tournament_status !== 'upcoming')   throw { status: 400, message: 'Tournament is not open' };
    const cap = MAX_TEAM_SIZE[team.format] || 2;
    if (team.member_count >= cap)                throw { status: 400, message: 'Team is already full' };
    if (team.entry_count >= team.max_players)    throw { status: 400, message: 'Tournament is full' };

    // Check user not already entered this tournament
    const already = await client.query(
      `SELECT id FROM entries WHERE user_id = $1 AND tournament_id = $2`,
      [userId, team.tournament_id]
    );
    if (already.rows.length) throw { status: 409, message: 'Already entered this tournament' };

    // Can't join own team twice
    const selfCheck = await client.query(
      `SELECT id FROM team_members WHERE team_id = $1 AND user_id = $2`,
      [id, userId]
    );
    if (selfCheck.rows.length) throw { status: 409, message: 'Already on this team' };

    await client.query(`INSERT INTO team_members (team_id, user_id) VALUES ($1, $2)`, [id, userId]);
    await client.query(
      `INSERT INTO entries (user_id, tournament_id, team_id, payment_status) VALUES ($1, $2, $3, 'pending')`,
      [userId, team.tournament_id, id]
    );

    await client.query('COMMIT');
    res.json({ message: 'Joined team successfully' });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.status) return res.status(err.status).json({ error: err.message });
    console.error(err);
    res.status(500).json({ error: 'Failed to join team' });
  } finally {
    client.release();
  }
}

// GET /api/teams?tournament_id=&open=true
async function listTeams(req, res) {
  const { tournament_id, open } = req.query;
  if (!tournament_id) return res.status(422).json({ error: 'tournament_id is required' });

  try {
    const { rows } = await db.query(
      `SELECT
         t.id, t.name, t.created_at, t.scorer_id,
         COUNT(tm.id)::int AS member_count,
         json_agg(
           json_build_object('id', u.id, 'name', u.name, 'handicap', u.handicap)
           ORDER BY tm.created_at
         ) FILTER (WHERE u.id IS NOT NULL) AS members
       FROM teams t
       JOIN tournaments tr ON tr.id = t.tournament_id
       LEFT JOIN team_members tm ON tm.team_id = t.id
       LEFT JOIN users u ON u.id = tm.user_id
       WHERE t.tournament_id = $1
       GROUP BY t.id, tr.format
       HAVING ($2::boolean IS FALSE
               OR COUNT(tm.id) < (CASE tr.format WHEN 'scramble' THEN 4 ELSE 2 END))
       ORDER BY t.created_at ASC`,
      [tournament_id, open === 'true']
    );
    res.json({ teams: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch teams' });
  }
}

// GET /api/teams/mine?tournament_id=
// Returns the requesting user's team for the given tournament, with members + scorer
// + each member's current hole_scores so the designated scorer can prefill.
async function getMyTeam(req, res) {
  const { tournament_id } = req.query;
  const userId = req.user.id;
  if (!tournament_id) return res.status(422).json({ error: 'tournament_id is required' });

  try {
    const { rows } = await db.query(
      `SELECT
         t.id, t.tournament_id, t.name, t.created_at, t.scorer_id,
         COUNT(tm.id)::int AS member_count,
         json_agg(
           json_build_object(
             'id',                  u.id,
             'name',                u.name,
             'handicap',            u.handicap,
             'profile_picture_url', u.profile_picture_url,
             'hole_scores',         e.hole_scores,
             'gross_score',         e.gross_score
           )
           ORDER BY tm.created_at
         ) FILTER (WHERE u.id IS NOT NULL) AS members
       FROM teams t
       JOIN team_members me ON me.team_id = t.id AND me.user_id = $1
       LEFT JOIN team_members tm ON tm.team_id = t.id
       LEFT JOIN users u ON u.id = tm.user_id
       LEFT JOIN entries e ON e.user_id = u.id AND e.tournament_id = t.tournament_id
       WHERE t.tournament_id = $2
       GROUP BY t.id`,
      [userId, tournament_id]
    );
    if (!rows.length) return res.status(404).json({ error: 'You are not on a team for this tournament' });
    res.json({ team: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch your team' });
  }
}

module.exports = { createTeam, joinTeam, listTeams, getMyTeam };

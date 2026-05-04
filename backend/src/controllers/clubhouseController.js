const crypto = require('crypto');
const db = require('../config/database');
const { notify } = require('./notificationController');
const { sendMail } = require('../config/mailer');

// Limit user-supplied fields to a known whitelist.
const EDITABLE_FIELDS = [
  'name', 'course_name', 'city', 'state', 'country', 'about',
  'logo_url', 'banner_url', 'primary_color', 'accent_color',
  'is_public', 'is_public_course', 'course_api_id',
];

function slugify(input) {
  return (input || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 60) || 'clubhouse';
}

// Ensure the slug we hand to the DB is unique. Append -2, -3, … as needed.
async function uniqueSlug(base) {
  let slug = base;
  let i = 2;
  while (true) {
    const { rows } = await db.query('SELECT 1 FROM clubhouses WHERE slug = $1', [slug]);
    if (!rows.length) return slug;
    slug = `${base}-${i++}`;
    if (i > 999) throw new Error('Could not generate a unique slug');
  }
}

// GET /api/clubhouses?city=&q=
// Public list. Only returns is_public = TRUE.
async function listPublicClubhouses(req, res) {
  const { city, q } = req.query;
  const conds = ['is_public = TRUE'];
  const vals = [];
  let i = 1;
  if (city) { conds.push(`city ILIKE $${i++}`); vals.push(`%${city}%`); }
  if (q)    { conds.push(`(name ILIKE $${i} OR course_name ILIKE $${i})`); vals.push(`%${q}%`); i++; }

  try {
    const { rows } = await db.query(
      `SELECT id, slug, name, course_name, city, state, country,
              logo_url, banner_url, primary_color, accent_color, is_public_course
       FROM clubhouses
       WHERE ${conds.join(' AND ')}
       ORDER BY name ASC
       LIMIT 200`,
      vals
    );
    res.json({ clubhouses: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to list clubhouses' });
  }
}

// GET /api/clubhouses/mine
async function listMyClubhouses(req, res) {
  try {
    const { rows } = await db.query(
      `SELECT * FROM clubhouses WHERE owner_id = $1 ORDER BY created_at DESC`,
      [req.user.id]
    );
    res.json({ clubhouses: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load your clubhouses' });
  }
}

// GET /api/clubhouses/:slug — public detail page
// Returns the clubhouse + its upcoming/active/completed tournaments.
async function getClubhouseBySlug(req, res) {
  const { slug } = req.params;
  try {
    const { rows } = await db.query(
      `SELECT c.*, u.name AS owner_name
       FROM clubhouses c
       JOIN users u ON u.id = c.owner_id
       WHERE c.slug = $1`,
      [slug]
    );
    if (!rows.length) return res.status(404).json({ error: 'Clubhouse not found' });
    const ch = rows[0];

    // Private clubhouses are visible only to the owner.
    if (!ch.is_public && (!req.user || req.user.id !== ch.owner_id)) {
      return res.status(404).json({ error: 'Clubhouse not found' });
    }

    const { rows: tournaments } = await db.query(
      `SELECT t.*,
              COUNT(DISTINCT e.user_id)::int AS player_count
       FROM tournaments t
       LEFT JOIN entries e ON e.tournament_id = t.id
       WHERE t.clubhouse_id = $1
       GROUP BY t.id
       ORDER BY t.date DESC`,
      [ch.id]
    );

    // Membership status of the current user
    let membershipStatus = null;
    let memberCount = 0;
    if (req.user) {
      const { rows: mem } = await db.query(
        'SELECT status FROM clubhouse_members WHERE clubhouse_id = $1 AND user_id = $2',
        [ch.id, req.user.id]
      );
      membershipStatus = mem.length ? mem[0].status : null;
    }
    const { rows: countRows } = await db.query(
      `SELECT COUNT(*)::int AS c FROM clubhouse_members
       WHERE clubhouse_id = $1 AND status = 'member'`,
      [ch.id]
    );
    memberCount = countRows[0].c;

    res.json({ clubhouse: ch, tournaments, membership_status: membershipStatus, member_count: memberCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load clubhouse' });
  }
}

// POST /api/clubhouses — admin only
async function createClubhouse(req, res) {
  if (!req.user.is_admin) return res.status(403).json({ error: 'Admin only' });
  const data = req.body || {};
  if (!data.name || !data.name.trim()) return res.status(422).json({ error: 'Name required' });

  // Public courses default to is_public = TRUE.
  const isPublic = data.is_public ?? (data.is_public_course === true);

  try {
    const slug = await uniqueSlug(slugify(data.name));
    const { rows } = await db.query(
      `INSERT INTO clubhouses
         (owner_id, slug, name, course_name, city, state, country, about,
          logo_url, banner_url, primary_color, accent_color,
          is_public, is_public_course, course_api_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,
               COALESCE($11,'#1B3D2C'), COALESCE($12,'#C9A84C'),
               $13, $14, $15)
       RETURNING *`,
      [
        req.user.id, slug, data.name.trim(),
        data.course_name || null, data.city || null, data.state || null, data.country || null,
        data.about || null, data.logo_url || null, data.banner_url || null,
        data.primary_color || null, data.accent_color || null,
        isPublic, data.is_public_course === true, data.course_api_id || null,
      ]
    );
    res.status(201).json({ clubhouse: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create clubhouse' });
  }
}

// PATCH /api/clubhouses/:id — owner only
async function updateClubhouse(req, res) {
  const { id } = req.params;
  try {
    const { rows: ownRows } = await db.query(
      'SELECT owner_id FROM clubhouses WHERE id = $1', [id]
    );
    if (!ownRows.length) return res.status(404).json({ error: 'Clubhouse not found' });
    if (ownRows[0].owner_id !== req.user.id && !req.user.is_admin) {
      return res.status(403).json({ error: 'Not your clubhouse' });
    }

    const updates = [];
    const values = [];
    let i = 1;
    for (const f of EDITABLE_FIELDS) {
      if (req.body[f] !== undefined) {
        updates.push(`${f} = $${i++}`);
        values.push(req.body[f]);
      }
    }
    if (!updates.length) return res.status(422).json({ error: 'No fields to update' });
    values.push(id);

    const { rows } = await db.query(
      `UPDATE clubhouses SET ${updates.join(', ')} WHERE id = $${i} RETURNING *`,
      values
    );
    res.json({ clubhouse: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update clubhouse' });
  }
}

// POST /api/clubhouses/:id/follow — public clubhouses
async function followClubhouse(req, res) {
  const { id } = req.params;
  try {
    const { rows: chRows } = await db.query(
      'SELECT id, slug, name, is_public FROM clubhouses WHERE id = $1',
      [id]
    );
    if (!chRows.length) return res.status(404).json({ error: 'Clubhouse not found' });
    if (!chRows[0].is_public) {
      return res.status(403).json({ error: 'Private clubhouse — invite required' });
    }
    await db.query(
      `INSERT INTO clubhouse_members (clubhouse_id, user_id, status)
       VALUES ($1, $2, 'member')
       ON CONFLICT (clubhouse_id, user_id) DO UPDATE SET status = 'member'`,
      [id, req.user.id]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to follow' });
  }
}

// DELETE /api/clubhouses/:id/follow
async function unfollowClubhouse(req, res) {
  const { id } = req.params;
  try {
    await db.query(
      'DELETE FROM clubhouse_members WHERE clubhouse_id = $1 AND user_id = $2',
      [id, req.user.id]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to leave' });
  }
}

// POST /api/clubhouses/:id/invite
// Body: { user_id?, email? }
//   user_id → existing user, fires in-app notification.
//   email   → if a user with that email exists, treat as user_id flow.
//             Otherwise create a pending email invite + send email.
// Owner-only.
async function inviteToClubhouse(req, res) {
  const { id } = req.params;
  const { user_id: targetId, email } = req.body || {};
  if (!targetId && !email) {
    return res.status(422).json({ error: 'Provide user_id or email' });
  }

  try {
    const { rows: chRows } = await db.query(
      'SELECT id, slug, name, course_name, owner_id FROM clubhouses WHERE id = $1', [id]
    );
    if (!chRows.length) return res.status(404).json({ error: 'Clubhouse not found' });
    const ch = chRows[0];
    if (ch.owner_id !== req.user.id && !req.user.is_admin) {
      return res.status(403).json({ error: 'Only the owner can invite' });
    }

    // ── 1. Resolve to a user_id if possible.
    let resolvedUserId = targetId || null;
    let resolvedEmail  = email ? email.trim().toLowerCase() : null;

    if (!resolvedUserId && resolvedEmail) {
      const { rows: ur } = await db.query(
        'SELECT id FROM users WHERE LOWER(email) = $1',
        [resolvedEmail]
      );
      if (ur.length) resolvedUserId = ur[0].id;
    }

    // ── 2a. Existing user — in-app invite + notification.
    if (resolvedUserId) {
      const { rows: targetRows } = await db.query(
        'SELECT id, name FROM users WHERE id = $1', [resolvedUserId]
      );
      if (!targetRows.length) return res.status(404).json({ error: 'User not found' });

      await db.query(
        `INSERT INTO clubhouse_members (clubhouse_id, user_id, status, invited_by)
         VALUES ($1, $2, 'invited', $3)
         ON CONFLICT (clubhouse_id, user_id) DO NOTHING`,
        [id, resolvedUserId, req.user.id]
      );

      await notify({
        userIds: [resolvedUserId],
        type:    'clubhouse_invite',
        title:   `${ch.name} invited you to their clubhouse`,
        body:    'Tap to view and accept.',
        link:    `/clubhouses/${ch.slug}`,
        payload: { clubhouse_id: ch.id, clubhouse_slug: ch.slug },
      });
      return res.json({ ok: true, kind: 'existing_user' });
    }

    // ── 2b. No existing user — email invite. Send signup link.
    if (!resolvedEmail || !/.+@.+\..+/.test(resolvedEmail)) {
      return res.status(422).json({ error: 'Valid email required' });
    }

    // Reuse pending invite for same (clubhouse, email) if one exists.
    const { rows: existing } = await db.query(
      `SELECT id, token FROM clubhouse_email_invites
       WHERE clubhouse_id = $1 AND LOWER(email) = $2 AND accepted_at IS NULL`,
      [id, resolvedEmail]
    );

    let token;
    if (existing.length) {
      token = existing[0].token;
    } else {
      token = crypto.randomBytes(24).toString('hex');
      await db.query(
        `INSERT INTO clubhouse_email_invites (clubhouse_id, email, token, invited_by)
         VALUES ($1, $2, $3, $4)`,
        [id, resolvedEmail, token, req.user.id]
      );
    }

    const courseName = ch.course_name || ch.name;
    const baseUrl = (process.env.APP_PUBLIC_URL || '').replace(/\/$/, '');
    const signupUrl = baseUrl ? `${baseUrl}/signup?invite=${token}` : null;

    const subject = `${courseName} HAS ASKED YOU TO JOIN THEIR CLUB`;
    const greetLine =
      `${courseName} has invited you to join their clubhouse on Clubhouse Stakes.`;
    const ctaText = signupUrl
      ? `Sign up here to accept: ${signupUrl}\n\n` +
        `Use the same email (${resolvedEmail}) when you sign up and we'll add you automatically.`
      : `Sign up at clubhousestakes.com using ${resolvedEmail} and we'll add you automatically.`;

    const text = `${subject}\n\n${greetLine}\n\n${ctaText}`;
    const html = `
      <div style="font-family:system-ui,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1B3D2C">
        <h1 style="font-size:18px;letter-spacing:1.5px;color:#C9A84C;margin:0 0 8px">CLUBHOUSE STAKES</h1>
        <h2 style="font-size:24px;font-weight:900;margin:0 0 16px">${escapeHtml(subject)}</h2>
        <p style="font-size:15px;line-height:1.5;margin:0 0 16px">${escapeHtml(greetLine)}</p>
        ${signupUrl ? `
          <p style="margin:24px 0">
            <a href="${signupUrl}" style="background:#1B3D2C;color:#fff;text-decoration:none;padding:12px 18px;border-radius:8px;font-weight:700">
              Accept invite &amp; sign up
            </a>
          </p>
          <p style="font-size:12px;color:#666;margin:0 0 4px">
            Use <strong>${escapeHtml(resolvedEmail)}</strong> when signing up — we'll add you to the club automatically.
          </p>
        ` : `
          <p style="font-size:14px;color:#444;margin:0 0 4px">
            Sign up at <a href="https://clubhousestakes.com">clubhousestakes.com</a> using
            <strong>${escapeHtml(resolvedEmail)}</strong> and we'll add you to the club automatically.
          </p>
        `}
      </div>`;

    await sendMail({ to: resolvedEmail, subject, text, html });

    res.json({ ok: true, kind: 'email_invite' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to invite' });
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// POST /api/clubhouses/:id/accept-invite
async function acceptInvite(req, res) {
  const { id } = req.params;
  try {
    const { rows } = await db.query(
      `UPDATE clubhouse_members
         SET status = 'member', joined_at = NOW()
       WHERE clubhouse_id = $1 AND user_id = $2 AND status = 'invited'
       RETURNING id`,
      [id, req.user.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'No pending invite' });
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed' });
  }
}

module.exports = {
  listPublicClubhouses,
  listMyClubhouses,
  getClubhouseBySlug,
  createClubhouse,
  updateClubhouse,
  followClubhouse,
  unfollowClubhouse,
  inviteToClubhouse,
  acceptInvite,
};

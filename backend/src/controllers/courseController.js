// Proxy for https://golfcourseapi.com — keeps the API key server-side.

const API_BASE = 'https://api.golfcourseapi.com/v1';

function authHeader() {
  const key = process.env.GOLFCOURSE_API_KEY;
  if (!key) return null;
  return `Key ${key}`;
}

async function callApi(path) {
  const auth = authHeader();
  if (!auth) {
    const err = new Error('Server is missing GOLFCOURSE_API_KEY');
    err.status = 500;
    throw err;
  }
  const resp = await fetch(`${API_BASE}${path}`, {
    headers: { Authorization: auth, Accept: 'application/json' },
  });
  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    const err = new Error(`golfcourseapi ${resp.status}: ${text || resp.statusText}`);
    err.status = resp.status === 404 ? 404 : 502;
    throw err;
  }
  return resp.json();
}

// GET /api/courses/search?q=<query>
async function searchCourses(req, res) {
  const q = (req.query.q || '').trim();
  if (q.length < 2) return res.json({ courses: [] });

  try {
    const data = await callApi(`/search?search_query=${encodeURIComponent(q)}`);
    const courses = (data.courses || []).map(simplifyCourse);
    res.json({ courses });
  } catch (err) {
    console.error('course search failed:', err.message);
    res.status(err.status || 500).json({ error: 'Course search failed' });
  }
}

// GET /api/courses/:id
async function getCourse(req, res) {
  try {
    const data = await callApi(`/courses/${encodeURIComponent(req.params.id)}`);
    res.json({ course: detailedCourse(data.course || data) });
  } catch (err) {
    console.error('course fetch failed:', err.message);
    res.status(err.status || 500).json({ error: 'Course fetch failed' });
  }
}

function simplifyCourse(c) {
  return {
    id:           c.id,
    club_name:    c.club_name || c.name,
    course_name:  c.course_name,
    location:     formatLocation(c.location),
  };
}

function detailedCourse(c) {
  // Tees come back as { male: [...], female: [...] } in the v1 schema.
  const teeGroups = c.tees || {};
  const allTees = [];
  for (const gender of ['male', 'female']) {
    for (const t of (teeGroups[gender] || [])) {
      const holes = (t.holes || []).map((h, idx) => ({
        number:  idx + 1,
        par:     h.par || 4,
        yardage: h.yardage || 0,
        handicap: h.handicap || (idx + 1),
      }));
      // Skip tees that don't have full 18-hole data — useless for scoring.
      if (holes.length !== 18) continue;
      allTees.push({
        id:               `${gender}-${t.tee_name}`,
        gender,
        tee_name:         t.tee_name,
        course_rating:    t.course_rating || null,
        slope_rating:     t.slope_rating  || null,
        total_yards:      t.total_yards   || holes.reduce((a, b) => a + b.yardage, 0),
        par_total:        t.par_total     || holes.reduce((a, b) => a + b.par, 0),
        holes,
      });
    }
  }
  return {
    id:          c.id,
    club_name:   c.club_name || c.name,
    course_name: c.course_name,
    location:    formatLocation(c.location),
    tees:        allTees,
  };
}

function formatLocation(loc) {
  if (!loc) return null;
  const parts = [loc.city, loc.state, loc.country].filter(Boolean);
  return parts.join(', ');
}

module.exports = { searchCourses, getCourse };

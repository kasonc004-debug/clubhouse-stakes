require('dotenv').config();
const express   = require('express');
const cors      = require('cors');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const path      = require('path');

const authRoutes        = require('./routes/auth');
const tournamentRoutes  = require('./routes/tournaments');
const teamRoutes        = require('./routes/teams');
const scoreRoutes       = require('./routes/scores');
const leaderboardRoutes = require('./routes/leaderboard');
const adminRoutes       = require('./routes/admin');
const userRoutes        = require('./routes/users');

const app  = express();
const PORT = process.env.PORT || 3000;

// Trust proxy so rate limiter sees real IP behind Railway/Cloudflare
app.set('trust proxy', 1);

// ── Security headers ────────────────────────────────────────
app.use(helmet({
  // API serves JSON, not HTML — disable CSP since browsers don't render our responses
  contentSecurityPolicy: false,
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// ── CORS ────────────────────────────────────────────────────
// In production, set CORS_ORIGINS to a comma-separated list of allowed origins.
// e.g. CORS_ORIGINS=https://www.clubhousestakes.com,https://clubhousestakes.com
// Leave unset in development to allow all origins.
const corsOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(s => s.trim())
  : null;

app.use(cors({
  origin: corsOrigins ?? true,
  credentials: true,
}));

// ── Body parsing (with size cap) ────────────────────────────
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// ── Rate limiters ───────────────────────────────────────────
// Auth: stricter limit to prevent brute-force on login/signup
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 min
  max: 20,                    // 20 attempts per 15 min per IP
  message: { error: 'Too many login attempts. Please try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// General API: catch runaway clients
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,   // 1 min
  max: 200,                   // 200 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
});

// ── Routes ──────────────────────────────────────────────────
app.use('/api/auth',         authLimiter, authRoutes);
app.use('/api/tournaments',  apiLimiter,  tournamentRoutes);
app.use('/api/teams',        apiLimiter,  teamRoutes);
app.use('/api/scores',       apiLimiter,  scoreRoutes);
app.use('/api/leaderboard',  apiLimiter,  leaderboardRoutes);
app.use('/api/admin',        apiLimiter,  adminRoutes);
app.use('/api/users',        apiLimiter,  userRoutes);

// ── Health check ────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', version: '1.0.0' }));

// ── Global error handler ────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, () => console.log(`Clubhouse Stakes API listening on port ${PORT}`));

module.exports = app;

require('dotenv').config();
const express  = require('express');
const cors     = require('cors');
const path     = require('path');

const authRoutes        = require('./routes/auth');
const tournamentRoutes  = require('./routes/tournaments');
const teamRoutes        = require('./routes/teams');
const scoreRoutes       = require('./routes/scores');
const leaderboardRoutes = require('./routes/leaderboard');
const adminRoutes       = require('./routes/admin');
const userRoutes        = require('./routes/users');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ──────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// ── Routes ──────────────────────────────────────────────────
app.use('/api/auth',         authRoutes);
app.use('/api/tournaments',  tournamentRoutes);
app.use('/api/teams',        teamRoutes);
app.use('/api/scores',       scoreRoutes);
app.use('/api/leaderboard',  leaderboardRoutes);
app.use('/api/admin',        adminRoutes);
app.use('/api/users',        userRoutes);

// ── Health check ────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', version: '1.0.0' }));

// ── Global error handler ────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

app.listen(PORT, () => console.log(`Clubhouse Stakes API listening on port ${PORT}`));

module.exports = app;

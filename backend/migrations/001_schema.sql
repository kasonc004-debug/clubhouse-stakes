-- ============================================================
-- Clubhouse Stakes — Initial Database Schema
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(255) NOT NULL,
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),
  apple_id      VARCHAR(255) UNIQUE,
  handicap      DECIMAL(4,1) DEFAULT 0 CHECK (handicap >= 0 AND handicap <= 54),
  city          VARCHAR(255),
  profile_picture_url TEXT,
  is_admin      BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TOURNAMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS tournaments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(255) NOT NULL,
  city          VARCHAR(255) NOT NULL,
  date          TIMESTAMPTZ NOT NULL,
  format        VARCHAR(50) NOT NULL CHECK (format IN ('individual', 'fourball')),
  sign_up_fee   DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (sign_up_fee >= 0),
  max_players   INTEGER NOT NULL CHECK (max_players > 0),
  fee_per       VARCHAR(20) DEFAULT 'player' CHECK (fee_per IN ('player', 'team')),
  status        VARCHAR(50) DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed')),
  course_name   VARCHAR(255),
  description   TEXT,
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TEAMS  (fourball only)
-- ============================================================
CREATE TABLE IF NOT EXISTS teams (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  name          VARCHAR(255),
  created_by    UUID NOT NULL REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TEAM MEMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS team_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id    UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (team_id, user_id)
);

-- ============================================================
-- ENTRIES
-- ============================================================
CREATE TABLE IF NOT EXISTS entries (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id),
  tournament_id  UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  team_id        UUID REFERENCES teams(id),
  hole_scores    INTEGER[] DEFAULT ARRAY[]::INTEGER[],
  gross_score    INTEGER,
  net_score      DECIMAL(6,1),
  payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded')),
  payment_intent VARCHAR(255),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, tournament_id)
);

-- ============================================================
-- PAYOUTS
-- ============================================================
CREATE TABLE IF NOT EXISTS payouts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id),
  user_id       UUID NOT NULL REFERENCES users(id),
  team_id       UUID REFERENCES teams(id),
  position      INTEGER NOT NULL,
  amount        DECIMAL(10,2) NOT NULL,
  status        VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_tournaments_city       ON tournaments(city);
CREATE INDEX IF NOT EXISTS idx_tournaments_date       ON tournaments(date);
CREATE INDEX IF NOT EXISTS idx_tournaments_status     ON tournaments(status);
CREATE INDEX IF NOT EXISTS idx_entries_tournament     ON entries(tournament_id);
CREATE INDEX IF NOT EXISTS idx_entries_user           ON entries(user_id);
CREATE INDEX IF NOT EXISTS idx_entries_team           ON entries(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team      ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user      ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_teams_tournament       ON teams(tournament_id);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_tournaments_updated_at
  BEFORE UPDATE ON tournaments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_entries_updated_at
  BEFORE UPDATE ON entries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

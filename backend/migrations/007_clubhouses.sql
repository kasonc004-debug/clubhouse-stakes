-- ============================================================
-- Migration 007: Clubhouses
--   First-class hosting entities. A clubhouse owns a page (logo,
--   banner, colors, about) and a roster of tournaments.
-- ============================================================

CREATE TABLE IF NOT EXISTS clubhouses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID NOT NULL REFERENCES users(id),
  slug            VARCHAR(80)  UNIQUE NOT NULL,
  name            VARCHAR(120) NOT NULL,
  course_name     VARCHAR(200),
  city            VARCHAR(120),
  state           VARCHAR(60),
  country         VARCHAR(60),
  about           TEXT,
  logo_url        TEXT,
  banner_url      TEXT,
  primary_color   VARCHAR(9)  DEFAULT '#1B3D2C',
  accent_color    VARCHAR(9)  DEFAULT '#C9A84C',
  is_public       BOOLEAN     DEFAULT TRUE,
  is_public_course BOOLEAN    DEFAULT FALSE,
  course_api_id   VARCHAR(100),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clubhouses_owner   ON clubhouses(owner_id);
CREATE INDEX IF NOT EXISTS idx_clubhouses_public  ON clubhouses(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS idx_clubhouses_city    ON clubhouses(city);

CREATE TRIGGER trg_clubhouses_updated_at
  BEFORE UPDATE ON clubhouses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Tournaments may belong to a clubhouse (optional for back-compat).
ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS clubhouse_id UUID REFERENCES clubhouses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tournaments_clubhouse ON tournaments(clubhouse_id);

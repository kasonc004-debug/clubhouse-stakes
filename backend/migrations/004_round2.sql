-- ============================================================
-- Migration 004: Round 2
--   - Handicap toggle on tournaments
--   - Custom hole pars per tournament
--   - Designated scorer per team (fourball)
-- ============================================================

ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS handicap_enabled BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS pars INTEGER[];

ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS scorer_id UUID REFERENCES users(id);

-- Backfill existing teams: scorer = creator
UPDATE teams SET scorer_id = created_by WHERE scorer_id IS NULL;

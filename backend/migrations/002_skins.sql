-- ============================================================
-- Migration 002: Skins game columns
-- ============================================================

ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS skins_fee DECIMAL(10,2) DEFAULT 0;

ALTER TABLE entries
  ADD COLUMN IF NOT EXISTS skins_entry BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_entries_skins ON entries(tournament_id) WHERE skins_entry = TRUE;

-- ============================================================
-- Migration 006: Scramble format
--   - Allow 'scramble' as a tournament format
-- ============================================================

ALTER TABLE tournaments DROP CONSTRAINT IF EXISTS tournaments_format_check;
ALTER TABLE tournaments
  ADD CONSTRAINT tournaments_format_check
  CHECK (format IN ('individual', 'fourball', 'scramble'));

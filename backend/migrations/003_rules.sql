-- ============================================================
-- Migration 003: Tournament rules
-- ============================================================

ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS rules TEXT;

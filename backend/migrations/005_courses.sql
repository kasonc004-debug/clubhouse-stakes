-- ============================================================
-- Migration 005: golfcourseapi.com integration
-- ============================================================

ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS yardages      INTEGER[],
  ADD COLUMN IF NOT EXISTS tee_name      VARCHAR(100),
  ADD COLUMN IF NOT EXISTS course_api_id VARCHAR(100);

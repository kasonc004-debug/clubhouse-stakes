-- ============================================================
-- Migration 011: Clubhouse staff
--   Lets a clubhouse owner promote members to "staff" so they can
--   edit the clubhouse page and post tournaments under it.
-- ============================================================

ALTER TABLE clubhouse_members
  ADD COLUMN IF NOT EXISTS role VARCHAR(20)
    NOT NULL DEFAULT 'member'
    CHECK (role IN ('member', 'staff'));

CREATE INDEX IF NOT EXISTS idx_chmem_role
  ON clubhouse_members(clubhouse_id, role)
  WHERE role = 'staff';

ALTER TABLE clubhouse_email_invites
  ADD COLUMN IF NOT EXISTS role VARCHAR(20)
    NOT NULL DEFAULT 'member'
    CHECK (role IN ('member', 'staff'));

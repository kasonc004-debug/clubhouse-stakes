-- ============================================================
-- Migration 008: Notifications + clubhouse memberships
--   Lets users follow/be invited to clubhouses and get notified
--   when invited or when their clubhouse posts a tournament.
-- ============================================================

-- ── Clubhouse memberships (follow / invite) ──
CREATE TABLE IF NOT EXISTS clubhouse_members (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clubhouse_id  UUID NOT NULL REFERENCES clubhouses(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
  status        VARCHAR(20) NOT NULL DEFAULT 'member'
                  CHECK (status IN ('invited', 'member')),
  invited_by    UUID REFERENCES users(id),
  joined_at     TIMESTAMPTZ DEFAULT NOW(),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (clubhouse_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chmem_user      ON clubhouse_members(user_id);
CREATE INDEX IF NOT EXISTS idx_chmem_clubhouse ON clubhouse_members(clubhouse_id);

-- ── Notifications ──
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          VARCHAR(40) NOT NULL,    -- e.g. 'clubhouse_invite', 'clubhouse_tournament'
  title         VARCHAR(200) NOT NULL,
  body          TEXT,
  link          TEXT,                    -- optional in-app deep link
  payload       JSONB    DEFAULT '{}'::jsonb,
  read_at       TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifs_user_created
  ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifs_unread
  ON notifications(user_id) WHERE read_at IS NULL;

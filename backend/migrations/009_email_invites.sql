-- ============================================================
-- Migration 009: Email-based clubhouse invites
--   Lets clubhouse owners invite people who don't yet have an
--   account. When that email later signs up, every pending invite
--   for that address is auto-attached as a clubhouse membership.
-- ============================================================

CREATE TABLE IF NOT EXISTS clubhouse_email_invites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clubhouse_id  UUID NOT NULL REFERENCES clubhouses(id) ON DELETE CASCADE,
  email         VARCHAR(255) NOT NULL,
  token         VARCHAR(64) UNIQUE NOT NULL,
  invited_by    UUID NOT NULL REFERENCES users(id),
  accepted_at   TIMESTAMPTZ,
  accepted_user UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chemail_email ON clubhouse_email_invites(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_chemail_token ON clubhouse_email_invites(token);
CREATE UNIQUE INDEX IF NOT EXISTS uq_chemail_pending
  ON clubhouse_email_invites(clubhouse_id, LOWER(email))
  WHERE accepted_at IS NULL;

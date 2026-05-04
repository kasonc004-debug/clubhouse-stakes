-- ============================================================
-- Migration 010: Pay-at-course tracking
--   Until Stripe lands, entries are confirmed online + paid in
--   person at the course. We track that explicitly so admins can
--   mark people paid as they collect cash.
-- ============================================================

ALTER TABLE entries
  ADD COLUMN IF NOT EXISTS skins_payment_status VARCHAR(50)
    DEFAULT 'pending'
    CHECK (skins_payment_status IN ('pending', 'paid', 'refunded'));

CREATE INDEX IF NOT EXISTS idx_entries_pay_status
  ON entries(tournament_id, payment_status);

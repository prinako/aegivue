ALTER TABLE recordings
  ADD COLUMN expires_at timestamptz;

CREATE INDEX recordings_expiry_idx
  ON recordings(expires_at)
  WHERE expires_at IS NOT NULL AND protected = false;

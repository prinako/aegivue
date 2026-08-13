-- Supports global newest-first and time-range recording queries. The existing
-- recordings_camera_start_idx covers per-camera newest-first and time ranges.
CREATE INDEX IF NOT EXISTS recordings_start_idx ON recordings(start_time DESC);

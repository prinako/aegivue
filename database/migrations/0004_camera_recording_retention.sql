ALTER TABLE recording_configs
  ADD COLUMN retention_days integer
  CHECK (retention_days IS NULL OR retention_days BETWEEN 1 AND 3650);

CREATE OR REPLACE VIEW camera_views AS
SELECT
  c.id,
  c.name,
  c.enabled,
  c.host,
  c.port,
  c.username,
  c.main_stream,
  c.sub_stream,
  r.enabled recording_enabled,
  r.mode recording_mode,
  r.pre_event_seconds,
  r.post_event_seconds,
  m.enabled motion_enabled,
  m.stream motion_stream,
  m.analysis_fps,
  m.sensitivity,
  c.created_at,
  c.updated_at,
  r.retention_days recording_retention_days
FROM cameras c
JOIN recording_configs r ON r.camera_id = c.id
JOIN motion_configs m ON m.camera_id = c.id;

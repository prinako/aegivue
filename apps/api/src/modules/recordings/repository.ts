import type { Pool } from "pg";

export interface RecordingView {
  id: string;
  cameraId: string;
  startTime: string;
  endTime: string | null;
  fileSize: number | null;
  container: string;
  videoCodec: string | null;
  audioCodec: string | null;
  width: number | null;
  height: number | null;
  fps: number | null;
  durationMs: number | null;
  playbackUrl: string;
  createdAt: string;
}

const map = (row: Record<string, unknown>): RecordingView => ({
  id: String(row.id),
  cameraId: String(row.camera_id),
  startTime: new Date(row.start_time as string).toISOString(),
  endTime: row.end_time ? new Date(row.end_time as string).toISOString() : null,
  fileSize: row.file_size === null ? null : Number(row.file_size),
  container: String(row.container),
  videoCodec: row.video_codec === null ? null : String(row.video_codec),
  audioCodec: row.audio_codec === null ? null : String(row.audio_codec),
  width: row.width === null ? null : Number(row.width),
  height: row.height === null ? null : Number(row.height),
  fps: row.fps === null ? null : Number(row.fps),
  durationMs: row.duration_ms === null ? null : Number(row.duration_ms),
  playbackUrl: `/api/v1/recordings/${String(row.id)}/media`,
  createdAt: new Date(row.created_at as string).toISOString(),
});

export class RecordingRepository {
  public constructor(private readonly db: Pool) {}
  public async list(limit: number, offset: number): Promise<RecordingView[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM recordings ORDER BY start_time DESC LIMIT $1 OFFSET $2",
      [limit, offset],
    );
    return rows.map(map);
  }
  public async find(id: string): Promise<RecordingView | null> {
    const { rows } = await this.db.query(
      "SELECT * FROM recordings WHERE id=$1",
      [id],
    );
    return rows[0] ? map(rows[0]) : null;
  }

  public async findFile(
    id: string,
  ): Promise<{ filePath: string; container: string } | null> {
    const { rows } = await this.db.query(
      "SELECT file_path, container FROM recordings WHERE id=$1",
      [id],
    );
    const row = rows[0] as Record<string, unknown> | undefined;
    return row
      ? { filePath: String(row.file_path), container: String(row.container) }
      : null;
  }
}

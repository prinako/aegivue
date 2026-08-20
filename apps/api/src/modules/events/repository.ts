import type { Pool } from "pg";

export type EventKind = "motion" | "object" | "manual" | "system";

export interface EventView {
  id: string;
  cameraId: string;
  cameraName: string;
  kind: EventKind;
  startedAt: string;
  endedAt: string | null;
  score: number | null;
  metadata: Record<string, unknown>;
}

const map = (row: Record<string, unknown>): EventView => ({
  id: String(row.id),
  cameraId: String(row.camera_id),
  cameraName: String(row.camera_name),
  kind: row.kind as EventKind,
  startedAt: new Date(row.started_at as string).toISOString(),
  endedAt: row.ended_at ? new Date(row.ended_at as string).toISOString() : null,
  score:
    row.score === null || row.score === undefined ? null : Number(row.score),
  metadata:
    row.metadata && typeof row.metadata === "object"
      ? (row.metadata as Record<string, unknown>)
      : {},
});

export class EventRepository {
  constructor(private readonly db: Pool) {}

  async list(
    limit: number,
    offset: number,
    kind?: EventKind,
    cameraId?: string,
  ): Promise<EventView[]> {
    const { rows } = await this.db.query(
      `SELECT
         e.id,
         e.camera_id,
         c.name AS camera_name,
         e.kind,
         e.started_at,
         e.ended_at,
         e.score,
         e.metadata
       FROM events e
       JOIN cameras c ON c.id = e.camera_id
       WHERE ($3::event_kind IS NULL OR e.kind = $3)
         AND ($4::varchar IS NULL OR e.camera_id = $4)
       ORDER BY e.started_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset, kind ?? null, cameraId ?? null],
    );
    return rows.map(map);
  }

  async count(kind?: EventKind, cameraId?: string): Promise<number> {
    const { rows } = await this.db.query<{ count: number }>(
      `SELECT count(*)::int AS count
       FROM events
       WHERE ($1::event_kind IS NULL OR kind = $1)
         AND ($2::varchar IS NULL OR camera_id = $2)`,
      [kind ?? null, cameraId ?? null],
    );
    return rows[0]?.count ?? 0;
  }

  async find(id: string): Promise<EventView | null> {
    const { rows } = await this.db.query(
      `SELECT
         e.id,
         e.camera_id,
         c.name AS camera_name,
         e.kind,
         e.started_at,
         e.ended_at,
         e.score,
         e.metadata
       FROM events e
       JOIN cameras c ON c.id = e.camera_id
       WHERE e.id = $1`,
      [id],
    );
    return rows[0] ? map(rows[0]) : null;
  }
}

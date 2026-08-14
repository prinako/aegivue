import type { Pool } from "pg";
import type { CreateCamera, UpdateCamera } from "./schemas.js";

export interface CameraView {
  id: string;
  name: string;
  enabled: boolean;
  connection: {
    protocol: "rtsp";
    host: string;
    port: number;
    username?: string;
    mainStream: string;
    subStream?: string;
  };
  recording: {
    enabled: boolean;
    mode: "continuous" | "motion";
    preEventSeconds: number;
    postEventSeconds: number;
  };
  motion: {
    enabled: boolean;
    stream: "main" | "sub";
    fps: number;
    sensitivity: number;
  };
  createdAt: string;
  updatedAt: string;
}

const map = (r: Record<string, unknown>): CameraView => ({
  id: String(r.id),
  name: String(r.name),
  enabled: Boolean(r.enabled),
  connection: {
    protocol: "rtsp",
    host: String(r.host),
    port: Number(r.port),
    ...(r.username ? { username: String(r.username) } : {}),
    mainStream: String(r.main_stream),
    ...(r.sub_stream ? { subStream: String(r.sub_stream) } : {}),
  },
  recording: {
    enabled: Boolean(r.recording_enabled),
    mode: r.recording_mode as "continuous" | "motion",
    preEventSeconds: Number(r.pre_event_seconds),
    postEventSeconds: Number(r.post_event_seconds),
  },
  motion: {
    enabled: Boolean(r.motion_enabled),
    stream: r.motion_stream as "main" | "sub",
    fps: Number(r.analysis_fps),
    sensitivity: Number(r.sensitivity),
  },
  createdAt: new Date(r.created_at as string).toISOString(),
  updatedAt: new Date(r.updated_at as string).toISOString(),
});

export class CameraRepository {
  constructor(private readonly db: Pool) {}

  async list(): Promise<CameraView[]> {
    const { rows } = await this.db.query(
      "SELECT * FROM camera_views ORDER BY name",
    );
    return rows.map(map);
  }

  async find(id: string): Promise<CameraView | null> {
    const { rows } = await this.db.query(
      "SELECT * FROM camera_views WHERE id=$1",
      [id],
    );
    return rows[0] ? map(rows[0]) : null;
  }

  async create(c: CreateCamera): Promise<CameraView> {
    const client = await this.db.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO cameras(id,name,enabled,host,port,username,password_secret,main_stream,sub_stream) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [
          c.id,
          c.name,
          c.enabled,
          c.connection.host,
          c.connection.port,
          c.connection.username ?? null,
          c.connection.password ?? null,
          c.connection.mainStream,
          c.connection.subStream ?? null,
        ],
      );
      await client.query(
        `INSERT INTO recording_configs(camera_id,enabled,mode,pre_event_seconds,post_event_seconds) VALUES($1,$2,$3,$4,$5)`,
        [
          c.id,
          c.recording.enabled,
          c.recording.mode,
          c.recording.preEventSeconds,
          c.recording.postEventSeconds,
        ],
      );
      await client.query(
        `INSERT INTO motion_configs(camera_id,enabled,stream,analysis_fps,sensitivity) VALUES($1,$2,$3,$4,$5)`,
        [
          c.id,
          c.motion.enabled,
          c.motion.stream,
          c.motion.fps,
          c.motion.sensitivity,
        ],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    const created = await this.find(c.id);
    if (!created) throw new Error("Camera disappeared after creation");
    return created;
  }

  async update(id: string, c: UpdateCamera): Promise<CameraView | null> {
    const client = await this.db.connect();
    try {
      await client.query("BEGIN");
      const cameraResult = await client.query(
        `UPDATE cameras
         SET name=$2, enabled=$3, host=$4, port=$5, username=$6,
             password_secret=COALESCE($7,password_secret), main_stream=$8,
             sub_stream=$9, updated_at=now()
         WHERE id=$1`,
        [
          id,
          c.name,
          c.enabled,
          c.connection.host,
          c.connection.port,
          c.connection.username ?? null,
          c.connection.password ?? null,
          c.connection.mainStream,
          c.connection.subStream ?? null,
        ],
      );
      if (cameraResult.rowCount !== 1) {
        await client.query("ROLLBACK");
        return null;
      }
      await client.query(
        `UPDATE recording_configs
         SET enabled=$2,mode=$3,pre_event_seconds=$4,post_event_seconds=$5
         WHERE camera_id=$1`,
        [
          id,
          c.recording.enabled,
          c.recording.mode,
          c.recording.preEventSeconds,
          c.recording.postEventSeconds,
        ],
      );
      await client.query(
        `UPDATE motion_configs
         SET enabled=$2,stream=$3,analysis_fps=$4,sensitivity=$5
         WHERE camera_id=$1`,
        [
          id,
          c.motion.enabled,
          c.motion.stream,
          c.motion.fps,
          c.motion.sensitivity,
        ],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
    return this.find(id);
  }

  async remove(id: string): Promise<boolean> {
    return (
      (await this.db.query("DELETE FROM cameras WHERE id=$1", [id]))
        .rowCount === 1
    );
  }

  async setEnabled(id: string, enabled: boolean): Promise<CameraView | null> {
    const result = await this.db.query(
      "UPDATE cameras SET enabled=$2,updated_at=now() WHERE id=$1",
      [id, enabled],
    );
    return result.rowCount === 1 ? this.find(id) : null;
  }
}

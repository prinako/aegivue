import Fastify from "fastify";
import type { FastifyInstance } from "fastify";
import type { Pool } from "pg";
import { afterEach, describe, expect, it, vi } from "vitest";
import { recordingRoutes } from "../src/modules/recordings/routes.js";

const apps: FastifyInstance[] = [];

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});

describe("recording timeline", () => {
  it("returns lightweight intervals ordered by start time", async () => {
    const { app, query } = await buildTestApp([
      timelineRow({
        id: "d01a30dc-9b3f-46de-a11b-5dc06d513f63",
        startTime: "2026-10-18T12:00:00Z",
        endTime: "2026-10-18T12:05:00Z",
      }),
    ]);

    const response = await app.inject({
      method: "GET",
      url: "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      items: [
        {
          recordingId: "d01a30dc-9b3f-46de-a11b-5dc06d513f63",
          cameraId: "front-door",
          startTime: "2026-10-18T12:00:00.000Z",
          endTime: "2026-10-18T12:05:00.000Z",
        },
      ],
    });
    expect(query).toHaveBeenCalledWith(
      expect.stringMatching(
        /start_time < \$2[\s\S]*COALESCE\([\s\S]*end_time[\s\S]*\) > \$1[\s\S]*ORDER BY start_time ASC, id ASC/,
      ),
      [
        new Date("2026-10-18T00:00:00.000Z"),
        new Date("2026-10-19T00:00:00.000Z"),
        5001,
      ],
    );
  });

  it.each([
    ["overlaps the beginning", "2026-10-17T23:55:00Z", "2026-10-18T00:05:00Z"],
    ["overlaps the end", "2026-10-18T23:55:00Z", "2026-10-19T00:05:00Z"],
    [
      "spans the complete window",
      "2026-10-17T23:00:00Z",
      "2026-10-19T01:00:00Z",
    ],
  ])("includes an interval that %s", async (_, startTime, endTime) => {
    const { app } = await buildTestApp([timelineRow({ startTime, endTime })]);

    const response = await app.inject({
      method: "GET",
      url: "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json<{ items: unknown[] }>().items).toHaveLength(1);
  });

  it("combines camera and overlap filters", async () => {
    const { app, query } = await buildTestApp([]);

    const response = await app.inject({
      method: "GET",
      url: "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z&cameraIds=front-door,garage",
    });

    expect(response.statusCode).toBe(200);
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("camera_id = ANY($3::varchar[])"),
      [
        new Date("2026-10-18T00:00:00.000Z"),
        new Date("2026-10-19T00:00:00.000Z"),
        ["front-door", "garage"],
        5001,
      ],
    );
  });

  it("returns an empty collection when no intervals overlap", async () => {
    const { app } = await buildTestApp([]);

    const response = await app.inject({
      method: "GET",
      url: "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ items: [] });
  });

  it.each([
    "/timeline?from=invalid&to=2026-10-19T00%3A00%3A00Z",
    "/timeline?from=2026-10-19T00%3A00%3A00Z&to=2026-10-18T00%3A00%3A00Z",
    "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-11-19T00%3A00%3A00Z",
    "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z&cameraIds=Front-Door",
  ])("rejects invalid timeline query %s", async (url) => {
    const { app, query } = await buildTestApp([]);

    const response = await app.inject({ method: "GET", url });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ code: "VALIDATION_ERROR" });
    expect(query).not.toHaveBeenCalled();
  });

  it("rejects an unbounded result instead of returning a truncated timeline", async () => {
    const rows = Array.from({ length: 5001 }, (_, index) =>
      timelineRow({
        id: `00000000-0000-4000-8000-${index.toString().padStart(12, "0")}`,
      }),
    );
    const { app } = await buildTestApp(rows);

    const response = await app.inject({
      method: "GET",
      url: "/timeline?from=2026-10-18T00%3A00%3A00Z&to=2026-10-19T00%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(422);
    expect(response.json()).toMatchObject({ code: "TIMELINE_RESULT_LIMIT" });
  });
});

function timelineRow({
  id = "d01a30dc-9b3f-46de-a11b-5dc06d513f63",
  startTime = "2026-10-18T12:00:00Z",
  endTime = "2026-10-18T12:05:00Z",
}: {
  id?: string;
  startTime?: string;
  endTime?: string;
} = {}) {
  return {
    id,
    camera_id: "front-door",
    start_time: startTime,
    end_time: endTime,
  };
}

async function buildTestApp(rows: Record<string, unknown>[]) {
  const query = vi.fn(async () => ({ rows }));
  const app = Fastify();
  app.decorate("db", { query } as unknown as Pool);
  await app.register(recordingRoutes, { storagePath: "/tmp" });
  apps.push(app);
  return { app, query };
}

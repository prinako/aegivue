import Fastify from "fastify";
import type { FastifyInstance } from "fastify";
import type { Pool } from "pg";
import { afterEach, describe, expect, it, vi } from "vitest";
import { recordingRoutes } from "../src/modules/recordings/routes.js";

const apps: FastifyInstance[] = [];

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});

describe("recording filters", () => {
  it("lists recordings without filters", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?page=2&pageSize=10",
    });

    expect(response.statusCode).toBe(200);
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("ORDER BY start_time DESC LIMIT $1 OFFSET $2"),
      [10, 10],
    );
    expect(query).toHaveBeenCalledWith(
      "SELECT count(*)::bigint AS count FROM recordings",
    );
  });

  it("filters list and count queries by one camera", async () => {
    const { app, query } = await buildTestApp(4);

    const response = await app.inject({
      method: "GET",
      url: "/?cameraIds=front-door",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      totalItems: 4,
      totalPages: 1,
    });
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("camera_id = ANY($1::varchar[])"),
      [["front-door"], 25, 0],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("camera_id = ANY($1::varchar[])"),
      [["front-door"]],
    );
  });

  it("filters paginated list and count queries by multiple cameras", async () => {
    const { app, query } = await buildTestApp(21);

    const response = await app.inject({
      method: "GET",
      url: "/?page=2&pageSize=10&cameraIds=front-door,garage",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      page: 2,
      pageSize: 10,
      totalItems: 21,
      totalPages: 3,
    });
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("camera_id = ANY($1::varchar[])"),
      [["front-door", "garage"], 10, 10],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("camera_id = ANY($1::varchar[])"),
      [["front-door", "garage"]],
    );
  });

  it("combines camera and date filters", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?cameraIds=front-door,garage&from=2026-10-17T08%3A00%3A00Z&to=2026-10-17T18%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    const from = new Date("2026-10-17T08:00:00.000Z");
    const to = new Date("2026-10-17T18:00:00.000Z");
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining(
        "camera_id = ANY($1::varchar[]) AND start_time >= $2 AND start_time <= $3",
      ),
      [["front-door", "garage"], from, to, 25, 0],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining(
        "camera_id = ANY($1::varchar[]) AND start_time >= $2 AND start_time <= $3",
      ),
      [["front-door", "garage"], from, to],
    );
  });

  it.each(["", "Front-Door", "front-door,", "front door"])(
    "rejects invalid camera IDs in %j",
    async (cameraIds) => {
      const { app, query } = await buildTestApp();

      const response = await app.inject({
        method: "GET",
        url: `/?cameraIds=${encodeURIComponent(cameraIds)}`,
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: "VALIDATION_ERROR" });
      expect(query).not.toHaveBeenCalled();
    },
  );

  it("applies a from timestamp to list and count queries", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?from=2026-10-17T08%3A00%3A00-03%3A00",
    });

    expect(response.statusCode).toBe(200);
    const from = new Date("2026-10-17T11:00:00.000Z");
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("WHERE start_time >= $1"),
      [from, 25, 0],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("WHERE start_time >= $1"),
      [from],
    );
  });

  it("applies a to timestamp to list and count queries", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?to=2026-10-17T18%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    const to = new Date("2026-10-17T18:00:00.000Z");
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("WHERE start_time <= $1"),
      [to, 25, 0],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("WHERE start_time <= $1"),
      [to],
    );
  });

  it("applies an inclusive timestamp range to paginated queries", async () => {
    const { app, query } = await buildTestApp(26);

    const response = await app.inject({
      method: "GET",
      url: "/?page=2&pageSize=10&from=2026-10-17T08%3A00%3A00Z&to=2026-10-17T18%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      page: 2,
      pageSize: 10,
      totalItems: 26,
      totalPages: 3,
    });
    const from = new Date("2026-10-17T08:00:00.000Z");
    const to = new Date("2026-10-17T18:00:00.000Z");
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("start_time >= $1 AND start_time <= $2"),
      [from, to, 10, 10],
    );
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining("start_time >= $1 AND start_time <= $2"),
      [from, to],
    );
  });

  it("rejects malformed timestamps", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?from=not-a-date",
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ code: "VALIDATION_ERROR" });
    expect(query).not.toHaveBeenCalled();
  });

  it("rejects ranges where from is after to", async () => {
    const { app, query } = await buildTestApp();

    const response = await app.inject({
      method: "GET",
      url: "/?from=2026-10-18T00%3A00%3A00Z&to=2026-10-17T00%3A00%3A00Z",
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({ code: "VALIDATION_ERROR" });
    expect(query).not.toHaveBeenCalled();
  });
});

async function buildTestApp(totalItems = 0) {
  const query = vi.fn(async (sql: string) => {
    if (sql.includes("count(*)"))
      return { rows: [{ count: String(totalItems) }] };
    return { rows: [] };
  });
  const app = Fastify();
  app.decorate("db", { query } as unknown as Pool);
  await app.register(recordingRoutes, { storagePath: "/tmp" });
  apps.push(app);
  return { app, query };
}

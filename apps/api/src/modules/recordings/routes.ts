import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { createReadStream } from "node:fs";
import { access } from "node:fs/promises";
import { resolve, sep } from "node:path";
import { RecordingRepository } from "./repository.js";

const pagination = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(25),
  offset: z.coerce.number().int().min(0).default(0),
});
const recordingId = z.string().uuid();

export const recordingRoutes: FastifyPluginAsync<{
  storagePath: string;
}> = async (app, options) => {
  const repository = new RecordingRepository(app.db);
  app.get("/", async (request, reply) => {
    const parsed = pagination.safeParse(request.query);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid pagination" });
    const items = await repository.list(parsed.data.limit, parsed.data.offset);
    return { items, limit: parsed.data.limit, offset: parsed.data.offset };
  });
  app.get("/:id", async (request, reply) => {
    const parsed = recordingId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid recording id" });
    const recording = await repository.find(parsed.data);
    return (
      recording ??
      reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" })
    );
  });
  app.get("/:id/media", async (request, reply) => {
    const parsed = recordingId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid recording id" });
    const recording = await repository.findFile(parsed.data);
    if (!recording)
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Recording not found" });
    const root = resolve(options.storagePath);
    const file = resolve(root, recording.filePath);
    if (!file.startsWith(`${root}${sep}`))
      return reply
        .code(400)
        .send({ code: "INVALID_PATH", message: "Invalid recording path" });
    try {
      await access(file);
    } catch {
      return reply.code(404).send({
        code: "FILE_NOT_FOUND",
        message: "Recording file is unavailable",
      });
    }
    return reply
      .type(
        recording.container === "mp4"
          ? "video/mp4"
          : "application/octet-stream",
      )
      .send(createReadStream(file));
  });
};

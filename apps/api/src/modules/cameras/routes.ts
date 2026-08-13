import type { FastifyPluginAsync } from "fastify";
import { createCamera, cameraId } from "./schemas.js";
import { CameraRepository } from "./repository.js";

export const cameraRoutes: FastifyPluginAsync = async (app) => {
  const repo = new CameraRepository(app.db);
  app.get("/", async () => repo.list());
  app.get("/:id", async (request, reply) => {
    const parsed = cameraId.safeParse((request.params as { id: string }).id);
    if (!parsed.success)
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid camera id" });
    const camera = await repo.find(parsed.data);
    return (
      camera ??
      reply.code(404).send({ code: "NOT_FOUND", message: "Camera not found" })
    );
  });
  app.post("/", async (request, reply) => {
    const parsed = createCamera.safeParse(request.body);
    if (!parsed.success)
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid camera configuration",
        details: parsed.error.flatten(),
      });
    try {
      const camera = await repo.create(parsed.data);
      if (camera.enabled) {
        try {
          await app.media.start(camera);
        } catch (error) {
          request.log.warn(
            { err: error, camera_id: camera.id },
            "Camera saved but media start was unavailable",
          );
        }
      }
      return await reply.code(201).send(camera);
    } catch (error) {
      if ((error as { code?: string }).code === "23505")
        return reply
          .code(409)
          .send({ code: "CAMERA_EXISTS", message: "Camera id already exists" });
      throw error;
    }
  });
  app.post("/:id/start", async (request, reply) => {
    try {
      return await app.media.start({
        id: (request.params as { id: string }).id,
      });
    } catch (error) {
      return reply
        .code(503)
        .send({ code: "MEDIA_UNAVAILABLE", message: (error as Error).message });
    }
  });
  app.post("/:id/stop", async (request, reply) => {
    try {
      return await app.media.stop((request.params as { id: string }).id);
    } catch (error) {
      return reply
        .code(503)
        .send({ code: "MEDIA_UNAVAILABLE", message: (error as Error).message });
    }
  });
  app.get("/:id/status", async (request, reply) => {
    try {
      return await app.media.status((request.params as { id: string }).id);
    } catch (error) {
      return reply
        .code(503)
        .send({ code: "MEDIA_UNAVAILABLE", message: (error as Error).message });
    }
  });
  app.delete("/:id", async (request, reply) =>
    (await repo.remove((request.params as { id: string }).id))
      ? reply.code(204).send()
      : reply
          .code(404)
          .send({ code: "NOT_FOUND", message: "Camera not found" }),
  );
};

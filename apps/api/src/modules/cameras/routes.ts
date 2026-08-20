import type {
  FastifyInstance,
  FastifyPluginAsync,
  FastifyReply,
  FastifyRequest,
} from "fastify";
import { createCamera, cameraId, updateCamera } from "./schemas.js";
import { CameraRepository } from "./repository.js";
import { MediaClientError } from "../../clients/media-client.js";

// --- Media & Error Helpers ---

function mediaFailure(reply: FastifyReply, error: unknown) {
  const kind = error instanceof MediaClientError ? error.kind : "internal";
  const statusMap: Record<string, number> = {
    not_found: 404,
    conflict: 409,
    invalid: 400,
    internal: 502,
  };

  return reply.code(statusMap[kind] ?? 503).send({
    code: `MEDIA_${kind.toUpperCase()}`,
    message: error instanceof Error ? error.message : "Media operation failed",
  });
}

async function safeStartMedia(
  app: FastifyInstance,
  request: FastifyRequest,
  camera: { id: string; enabled: boolean },
) {
  if (!camera.enabled) return;
  try {
    await app.media.start(camera);
  } catch (error) {
    request.log.warn(
      { err: error, camera_id: camera.id },
      "Media start deferred or unavailable",
    );
  }
}

async function safeStopMedia(
  app: FastifyInstance,
  request: FastifyRequest,
  id: string,
  contextOp: string,
) {
  try {
    await app.media.stop(id);
  } catch (error) {
    if (!(error instanceof MediaClientError && error.kind === "not_found")) {
      request.log.warn(
        { camera_id: id, operation: contextOp, status: "deferred" },
        "Camera media worker could not be stopped",
      );
    }
  }
}

async function handleMediaAction(
  request: FastifyRequest<{ Params: { id: string } }>,
  reply: FastifyReply,
  action: () => Promise<unknown>,
  operation: string,
) {
  try {
    return await action();
  } catch (error) {
    request.log.warn(
      { camera_id: request.params.id, operation, status: "failed" },
      "Media operation failed",
    );
    return mediaFailure(reply, error);
  }
}

async function stopMediaForDelete(
  app: FastifyInstance,
  reply: FastifyReply,
  id: string,
): Promise<boolean> {
  try {
    await app.media.stop(id);
    return true;
  } catch (error) {
    if (error instanceof MediaClientError && error.kind === "not_found") {
      return true;
    }
    mediaFailure(reply, error);
    return false;
  }
}

async function removeCameraOrDisable(
  repo: CameraRepository,
  reply: FastifyReply,
  id: string,
) {
  try {
    const removed = await repo.remove(id);
    if (!removed) {
      return await reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Camera not found" });
    }
    return await reply.code(204).send();
  } catch (error) {
    if ((error as { code?: string }).code === "23503") {
      await repo.setEnabled(id, false);
      return reply.code(409).send({
        code: "CAMERA_HAS_RECORDINGS",
        message: "Camera has recordings and was disabled instead of deleted",
      });
    }
    throw error;
  }
}

// --- Routes ---

export const cameraRoutes: FastifyPluginAsync = async (app) => {
  const repo = new CameraRepository(app.db);

  app.get("/", async () => repo.list());

  app.get<{ Params: { id: string } }>("/:id", async (request, reply) => {
    const parsed = cameraId.safeParse(request.params.id);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ code: "VALIDATION_ERROR", message: "Invalid camera id" });
    }

    const camera = await repo.find(parsed.data);
    if (!camera) {
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Camera not found" });
    }

    return camera;
  });

  app.post("/", async (request, reply) => {
    const parsed = createCamera.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid camera configuration",
        details: parsed.error.flatten(),
      });
    }

    try {
      const camera = await repo.create(parsed.data);
      await safeStartMedia(app, request, camera);
      return await reply.code(201).send(camera);
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        return reply
          .code(409)
          .send({ code: "CAMERA_EXISTS", message: "Camera id already exists" });
      }
      throw error;
    }
  });

  app.post<{ Params: { id: string } }>("/:id/start", async (request, reply) =>
    handleMediaAction(
      request,
      reply,
      () => app.media.start({ id: request.params.id }),
      "start",
    ),
  );

  app.post<{ Params: { id: string } }>("/:id/stop", async (request, reply) =>
    handleMediaAction(
      request,
      reply,
      () => app.media.stop(request.params.id),
      "stop",
    ),
  );

  app.get<{ Params: { id: string } }>("/:id/status", async (request, reply) =>
    handleMediaAction(
      request,
      reply,
      () => app.media.status(request.params.id),
      "status",
    ),
  );

  app.patch<{ Params: { id: string } }>("/:id", async (request, reply) => {
    const parsed = updateCamera.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid camera configuration",
        details: parsed.error.flatten(),
      });
    }

    const { id } = request.params;
    const previous = await repo.find(id);
    if (!previous) {
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Camera not found" });
    }

    const camera = await repo.update(id, parsed.data);
    if (!camera) {
      return reply
        .code(404)
        .send({ code: "NOT_FOUND", message: "Camera not found" });
    }

    await safeStopMedia(app, request, id, "stop-before-update");
    await safeStartMedia(app, request, camera);

    return camera;
  });

  app.delete<{ Params: { id: string } }>("/:id", async (request, reply) => {
    const { id } = request.params;
    if (!(await stopMediaForDelete(app, reply, id))) return;
    return removeCameraOrDisable(repo, reply, id);
  });
};

import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { EventRepository } from "./repository.js";

const pagination = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
  kind: z.enum(["motion", "object", "manual", "system"]).optional(),
  cameraId: z
    .string()
    .regex(/^[a-z0-9][a-z0-9_-]{2,63}$/)
    .optional(),
});
const eventId = z.string().uuid();

export const eventRoutes: FastifyPluginAsync = async (app) => {
  const repository = new EventRepository(app.db);

  app.get("/", async (request, reply) => {
    const parsed = pagination.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid event query",
      });
    }

    const { page, pageSize, kind, cameraId } = parsed.data;
    const offset = (page - 1) * pageSize;
    const [items, totalItems] = await Promise.all([
      repository.list(pageSize, offset, kind, cameraId),
      repository.count(kind, cameraId),
    ]);

    return {
      items,
      page,
      pageSize,
      totalItems,
      totalPages: Math.ceil(totalItems / pageSize),
    };
  });

  app.get("/:id", async (request, reply) => {
    const parsed = eventId.safeParse((request.params as { id: string }).id);
    if (!parsed.success) {
      return reply.code(400).send({
        code: "VALIDATION_ERROR",
        message: "Invalid event id",
      });
    }

    const event = await repository.find(parsed.data);
    return (
      event ??
      reply.code(404).send({ code: "NOT_FOUND", message: "Event not found" })
    );
  });
};

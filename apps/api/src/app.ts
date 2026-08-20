import Fastify from "fastify";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import { databasePlugin } from "./database/plugin.js";
import { cameraRoutes } from "./modules/cameras/routes.js";
import { eventRoutes } from "./modules/events/routes.js";
import { recordingRoutes } from "./modules/recordings/routes.js";
import { MediaClient } from "./clients/media-client.js";
import type { Config } from "./config/env.js";

export async function buildApp(config: Config) {
  const app = Fastify({
    logger: {
      level: config.AEGIVUE_LOG_LEVEL,
      base: { service: "aegivue-api" },
    },
    trustProxy: config.AEGIVUE_TRUST_PROXY,
  });
  await app.register(swagger, {
    openapi: { info: { title: "Aegivue API", version: "0.1.0" } },
  });
  await app.register(swaggerUi, { routePrefix: "/docs" });
  await app.register(databasePlugin, {
    connectionString: config.AEGIVUE_DATABASE_URL,
  });
  app.decorate("media", new MediaClient(config.AEGIVUE_MEDIA_URL));
  app.setErrorHandler((error, request, reply) => {
    const httpError = error as { statusCode?: number; message?: string };
    const status =
      httpError.statusCode && httpError.statusCode < 500
        ? httpError.statusCode
        : 500;
    request.log.error({ err: error, operation: "request" }, "Request failed");
    void reply.code(status).send({
      code: status === 500 ? "INTERNAL_ERROR" : "REQUEST_ERROR",
      message:
        status === 500
          ? "Internal server error"
          : (httpError.message ?? "Request failed"),
    });
  });
  app.get("/api/v1/health", async (_request, reply) => {
    try {
      await app.db.query("SELECT 1");
      return { status: "ok", service: "aegivue-api" };
    } catch {
      return reply
        .code(503)
        .send({ status: "unavailable", service: "aegivue-api" });
    }
  });
  await app.register(cameraRoutes, { prefix: "/api/v1/cameras" });
  await app.register(eventRoutes, { prefix: "/api/v1/events" });
  await app.register(recordingRoutes, {
    prefix: "/api/v1/recordings",
    storagePath: config.AEGIVUE_STORAGE_PATH,
  });
  return app;
}

import { buildApp } from "./app.js";
import { loadConfig } from "./config/env.js";

const config = loadConfig();
const app = await buildApp(config);
const shutdown = async (signal: string) => {
  app.log.info({ signal }, "Graceful shutdown started");
  await app.close();
  process.exit(0);
};
process.once("SIGINT", () => void shutdown("SIGINT"));
process.once("SIGTERM", () => void shutdown("SIGTERM"));
await app.listen({
  host: config.VIGILO_API_HOST,
  port: config.VIGILO_API_PORT,
});
